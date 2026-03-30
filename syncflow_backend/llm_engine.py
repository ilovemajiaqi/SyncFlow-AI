import json
import re
from dataclasses import dataclass
from datetime import datetime, timedelta

from openai import OpenAI

from config import get_settings
from models import ParsedIntent


DEFAULT_ARK_BASE_URL = "https://ark.cn-beijing.volces.com/api/v3"
DEFAULT_ARK_MODEL_NAME = "doubao-1-5-pro-32k-250115"
_WEEKDAY_MAP = {
    "一": 0,
    "二": 1,
    "三": 2,
    "四": 3,
    "五": 4,
    "六": 5,
    "日": 6,
    "天": 6,
}
_WEEK_PREFIX_OFFSET = {
    "本周": 0,
    "这周": 0,
    "本星期": 0,
    "这星期": 0,
    "下周": 1,
    "下星期": 1,
    "下下周": 2,
    "下下星期": 2,
}
_WEEKDAY_PATTERN = re.compile(
    r"(?P<prefix>下下周|下下星期|下周|下星期|本周|这周|本星期|这星期)(?P<day>[一二三四五六日天])"
)

SYSTEM_PROMPT_TEMPLATE = """# Role
你是一个高精度的日程调度意图解析引擎（SyncFlow AI Core）。你的唯一职责是将用户的自然语言输入，转化为严格符合规范的 JSON 格式数据。

# Task
分析用户的自然语言输入，识别出所有与日程管理相关的意图（新增、删除、修改），并提取关键参数。

# Rules
1. 绝对的 JSON 格式：你必须且只能输出合法的 JSON 字符串。禁止输出任何解释性文本、禁止使用 Markdown 代码块包裹，只需输出 JSON 本身。
2. 时间推算逻辑：结合系统提供的 [Current Time]，将用户口语化的时间转化为 ISO 8601 标准的绝对时间格式（YYYY-MM-DDTHH:MM:SS）。若未指定具体时长，默认事件时长为 {default_duration} 分钟。
3. 周次规则：本周/这周表示当前自然周，下周表示紧邻的下一自然周，下下周表示再下一自然周。若输入里已经给出明确日期，优先按明确日期处理。
4. 意图拆解：提取多个动作放入 actions 数组。

# Output Schema
{{
  "intent": "schedule_update",
  "actions": [
    {{
      "action_type": "add" | "delete" | "update",
      "event_title": "事件名称",
      "target_keyword": "原事件关键词",
      "start_time": "YYYY-MM-DDTHH:MM:SS",
      "duration_minutes": 整数
    }}
  ]
}}

[Current Time] {current_time}"""


@dataclass(frozen=True)
class RuntimeLLMConfig:
    api_key: str | None
    base_url: str
    model_name: str
    default_duration_minutes: int


def get_system_prompt(default_duration_minutes: int) -> str:
    current_time = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    return SYSTEM_PROMPT_TEMPLATE.format(
        current_time=current_time,
        default_duration=default_duration_minutes,
    )


def build_runtime_config(
    *,
    api_key: str | None = None,
    base_url: str | None = None,
    model_name: str | None = None,
    default_duration_minutes: int | None = None,
) -> RuntimeLLMConfig:
    duration = default_duration_minutes or 0
    if duration <= 0:
        duration = 60

    normalized_api_key = (api_key or '').strip() or None
    if not normalized_api_key:
        raise ValueError("未配置用户 API Key，无法调用豆包模型")

    return RuntimeLLMConfig(
        api_key=normalized_api_key,
        base_url=(base_url or DEFAULT_ARK_BASE_URL).strip(),
        model_name=(model_name or DEFAULT_ARK_MODEL_NAME).strip(),
        default_duration_minutes=duration,
    )


def _normalize_relative_weekdays(text: str, reference: datetime | None = None) -> str:
    now = reference or datetime.now()
    week_start = now - timedelta(days=now.weekday())

    def repl(match: re.Match[str]) -> str:
        prefix = match.group('prefix')
        day = match.group('day')
        offset = _WEEK_PREFIX_OFFSET[prefix]
        weekday = _WEEKDAY_MAP[day]
        target_date = week_start + timedelta(days=offset * 7 + weekday)
        return f"{target_date.strftime('%Y-%m-%d')}"

    return _WEEKDAY_PATTERN.sub(repl, text)


def _get_client(config: RuntimeLLMConfig) -> OpenAI:
    return OpenAI(api_key=config.api_key, base_url=config.base_url)


def _strip_markdown_fence(text: str) -> str:
    content = text.strip()
    if content.startswith("```json"):
        content = content[7:]
    elif content.startswith("```"):
        content = content[3:]
    if content.endswith("```"):
        content = content[:-3]
    return content.strip()


def _mock_parse_user_intent(text: str, default_duration_minutes: int) -> ParsedIntent:
    now = datetime.now().replace(minute=0, second=0, microsecond=0)
    text = _normalize_relative_weekdays(text, now)
    actions = []

    add_time = now + timedelta(days=1, hours=15 - now.hour)
    explicit_date_match = re.search(r"(\d{4}-\d{2}-\d{2})", text)
    if any(token in text for token in ["明天", "后天", "开会", "会议", "安排", "新增"]) or explicit_date_match:
        if explicit_date_match:
            add_time = datetime.strptime(explicit_date_match.group(1), "%Y-%m-%d").replace(
                hour=add_time.hour,
                minute=0,
                second=0,
                microsecond=0,
            )
        elif "后天" in text:
            add_time += timedelta(days=1)
        title = "开会" if "开会" in text or "会议" in text else "新日程"
        hour_match = re.search(r"(\d{1,2})点", text)
        if hour_match:
            parsed_hour = int(hour_match.group(1))
            if any(token in text for token in ["下午", "晚上"]) and parsed_hour < 12:
                parsed_hour += 12
            add_time = add_time.replace(hour=parsed_hour)
        duration_match = re.search(r"(\d{1,3})\s*(小时|个小时|分)", text)
        if duration_match:
            raw_duration = int(duration_match.group(1))
            duration = raw_duration * 60 if '小时' in duration_match.group(2) else raw_duration
        else:
            duration = default_duration_minutes
        actions.append(
            {
                "action_type": "add",
                "event_title": title,
                "target_keyword": title,
                "start_time": add_time.strftime("%Y-%m-%dT%H:%M:%S"),
                "duration_minutes": duration,
            }
        )

    if any(token in text for token in ["取消", "删除", "移除"]):
        target = "打球" if "打球" in text else "聚餐" if "聚餐" in text else None
        actions.append(
            {
                "action_type": "delete",
                "event_title": None,
                "target_keyword": target,
                "start_time": None,
                "duration_minutes": default_duration_minutes,
            }
        )

    if "改到" in text or "改成" in text:
        actions.append(
            {
                "action_type": "update",
                "event_title": "更新后的日程",
                "target_keyword": "原日程",
                "start_time": (now + timedelta(days=1)).strftime("%Y-%m-%dT%H:%M:%S"),
                "duration_minutes": default_duration_minutes,
            }
        )

    if not actions:
        actions.append(
            {
                "action_type": "add",
                "event_title": text.strip()[:20] or "待处理事项",
                "target_keyword": text.strip()[:20] or "待处理事项",
                "start_time": (now + timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%S"),
                "duration_minutes": default_duration_minutes,
            }
        )

    return ParsedIntent.model_validate({"intent": "schedule_update", "actions": actions})


def parse_user_intent(
    text: str,
    *,
    api_key: str | None = None,
    base_url: str | None = None,
    model_name: str | None = None,
    default_duration_minutes: int | None = None,
) -> ParsedIntent:
    settings = get_settings()
    runtime_config = build_runtime_config(
        api_key=api_key,
        base_url=base_url,
        model_name=model_name,
        default_duration_minutes=default_duration_minutes,
    )
    normalized_text = _normalize_relative_weekdays(text)

    if settings.syncflow_mock_llm:
        return _mock_parse_user_intent(normalized_text, runtime_config.default_duration_minutes)

    client = _get_client(runtime_config)
    response = client.chat.completions.create(
        model=runtime_config.model_name,
        messages=[
            {"role": "system", "content": get_system_prompt(runtime_config.default_duration_minutes)},
            {"role": "user", "content": normalized_text},
        ],
        temperature=0.1,
    )

    raw_content = response.choices[0].message.content or ""
    cleaned_content = _strip_markdown_fence(raw_content)
    parsed = json.loads(cleaned_content)
    return ParsedIntent.model_validate(parsed)
