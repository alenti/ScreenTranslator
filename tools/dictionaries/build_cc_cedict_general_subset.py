#!/usr/bin/env python3
"""Build a general CC-CEDICT subset for Quick Look overlay experiments.

This tooling-only script creates a broad Chinese-to-English fallback dictionary
candidate from a full CC-CEDICT SQLite database. It is intentionally separate
from the shopping/logistics reducer so both experiments remain available.
Generated data belongs in /tmp and is not bundled into the iOS app.
"""

from __future__ import annotations

import argparse
import json
import re
import sqlite3
import sys
import unicodedata
from dataclasses import asdict, dataclass
from pathlib import Path


LICENSE_SOURCE = "CC-CEDICT CC BY-SA 4.0"
APP_OVERRIDE_SOURCE = "ScreenTranslator app-owned phrase override"
DEFAULT_MAX_DISPLAY_LENGTH = 28

PHRASE_DISPLAY_OVERRIDES = {
    "对方正在输入": "typing...",
    "暂无数据": "no data",
    "暂无消息": "no messages",
    "暂无内容": "no content",
    "地铁路线": "metro route",
    "退出登录": "log out",
    "输入验证码": "verification code",
    "绑定手机号": "bind phone",
    "解绑手机号": "unbind phone",
    "退款处理中": "refund processing",
    "快递已发货": "shipped",
    "物流已发货": "shipped",
    "订单已取消": "order canceled",
    "支付失败": "payment failed",
    "支付成功": "payment successful",
    "网络错误请重试": "network error · retry",
    "打开设置": "open settings",
    "保存图片": "save image",
    "复制链接": "copy link",
    "查看位置": "view location",
    "附近餐厅": "nearby restaurants",
    "预约成功": "booking successful",
    "修改地址": "change address",
    "上传文件": "upload file",
    "发送消息": "send message",
    "权限不足": "insufficient permission",
    "加载中": "loading",
    "请稍后": "please wait",
    "无法连接": "cannot connect",
    "已过期": "expired",
    "不支持": "not supported",
    "20点抢": "grab at 20:00",
    "外箱": "outer box",
    "木架": "wooden crate",
    "入仓费": "warehouse fee",
    "私人仓": "private warehouse",
    "国际运输": "intl shipping",
    "明显标签": "clear label",
    "贴上": "stick on",
    "包装费": "packaging fee",
    "出口": "exit/export",
    "加收": "extra charge",
    "新版洗面奶": "cleansing lotion",
}


@dataclass(frozen=True)
class Category:
    name: str
    chinese_seeds: tuple[str, ...]
    english_seeds: tuple[str, ...]


CATEGORIES = [
    Category(
        name="common_app_ui",
        chinese_seeds=(
            "打开",
            "关闭",
            "返回",
            "确认",
            "取消",
            "保存",
            "删除",
            "编辑",
            "复制",
            "粘贴",
            "分享",
            "搜索",
            "设置",
            "更多",
            "全部",
            "完成",
            "下一步",
            "上一步",
            "继续",
            "跳过",
        ),
        english_seeds=(
            "open",
            "close",
            "return",
            "back",
            "confirm",
            "cancel",
            "save",
            "delete",
            "edit",
            "copy",
            "paste",
            "share",
            "search",
            "settings",
            "more",
            "done",
            "complete",
            "next",
            "previous",
            "continue",
            "skip",
        ),
    ),
    Category(
        name="accounts_login",
        chinese_seeds=(
            "登录",
            "注册",
            "账号",
            "帐号",
            "密码",
            "验证码",
            "手机号",
            "邮箱",
            "退出登录",
            "忘记密码",
            "绑定",
            "解绑",
        ),
        english_seeds=(
            "login",
            "log in",
            "register",
            "account",
            "password",
            "verification code",
            "phone number",
            "mobile number",
            "email",
            "logout",
            "log out",
            "bind",
            "unbind",
        ),
    ),
    Category(
        name="status_errors",
        chinese_seeds=(
            "成功",
            "失败",
            "错误",
            "加载中",
            "请稍后",
            "暂无",
            "网络错误",
            "重试",
            "无法连接",
            "已过期",
            "不支持",
            "权限",
            "允许",
            "拒绝",
            "数据",
        ),
        english_seeds=(
            "success",
            "successful",
            "failed",
            "failure",
            "error",
            "loading",
            "please wait",
            "network error",
            "retry",
            "reconnect",
            "connect",
            "expired",
            "unsupported",
            "permission",
            "allow",
            "deny",
            "refuse",
        ),
    ),
    Category(
        name="chat_messages",
        chinese_seeds=(
            "消息",
            "发送",
            "接收",
            "已读",
            "未读",
            "对方正在输入",
            "联系人",
            "群聊",
            "语音",
            "图片",
            "视频",
            "文件",
            "位置",
            "链接",
            "上传",
            "下载",
        ),
        english_seeds=(
            "message",
            "send",
            "receive",
            "read",
            "unread",
            "typing",
            "contact",
            "group chat",
            "voice",
            "image",
            "picture",
            "video",
            "file",
            "location",
            "link",
            "upload",
            "download",
        ),
    ),
    Category(
        name="payment_order_shopping",
        chinese_seeds=(
            "支付",
            "付款",
            "订单",
            "退款",
            "购物车",
            "购物",
            "优惠券",
            "优惠",
            "发货",
            "收货",
            "地址",
            "快递",
            "物流",
            "价格",
            "数量",
            "付款",
            "支付失败",
        ),
        english_seeds=(
            "pay",
            "payment",
            "order",
            "refund",
            "shopping cart",
            "cart",
            "shopping",
            "coupon",
            "discount",
            "ship",
            "send goods",
            "receive",
            "address",
            "express",
            "logistics",
            "price",
            "quantity",
        ),
    ),
    Category(
        name="delivery_logistics",
        chinese_seeds=(
            "运输",
            "包装",
            "仓库",
            "标签",
            "货物",
            "箱子",
            "运费",
            "包裹",
            "配送",
            "外箱",
            "木架",
            "国际运输",
        ),
        english_seeds=(
            "transport",
            "shipping",
            "delivery",
            "packaging",
            "package",
            "warehouse",
            "label",
            "goods",
            "cargo",
            "box",
            "freight",
            "parcel",
        ),
    ),
    Category(
        name="forms_personal_info",
        chinese_seeds=(
            "姓名",
            "电话",
            "地址",
            "身份证",
            "生日",
            "性别",
            "国家",
            "城市",
            "地区",
            "公司",
            "学校",
        ),
        english_seeds=(
            "name",
            "phone",
            "telephone",
            "address",
            "identity card",
            "id card",
            "birthday",
            "gender",
            "country",
            "city",
            "region",
            "company",
            "school",
        ),
    ),
    Category(
        name="time_date",
        chinese_seeds=(
            "今天",
            "明天",
            "昨天",
            "时间",
            "日期",
            "小时",
            "分钟",
            "到期",
            "剩余",
            "星期",
            "周",
            "月",
            "年",
            "天",
        ),
        english_seeds=(
            "today",
            "tomorrow",
            "yesterday",
            "time",
            "date",
            "hour",
            "minute",
            "day",
            "week",
            "month",
            "year",
            "expire",
            "remaining",
        ),
    ),
    Category(
        name="navigation_location",
        chinese_seeds=(
            "地图",
            "路线",
            "附近",
            "距离",
            "位置",
            "目的地",
            "出发",
            "到达",
            "公交",
            "地铁",
            "打车",
        ),
        english_seeds=(
            "map",
            "route",
            "nearby",
            "distance",
            "location",
            "destination",
            "depart",
            "departure",
            "arrive",
            "arrival",
            "bus",
            "subway",
            "taxi",
        ),
    ),
    Category(
        name="food_services",
        chinese_seeds=(
            "外卖",
            "餐厅",
            "菜单",
            "订单",
            "配送",
            "评价",
            "预约",
            "排队",
            "餐",
            "饭店",
        ),
        english_seeds=(
            "takeout",
            "home delivery",
            "restaurant",
            "menu",
            "order",
            "delivery",
            "review",
            "rating",
            "appointment",
            "reservation",
            "queue",
        ),
    ),
    Category(
        name="product_details",
        chinese_seeds=(
            "商品",
            "产品",
            "详情",
            "规格",
            "颜色",
            "尺寸",
            "尺码",
            "材质",
            "材料",
            "库存",
            "现货",
            "专柜",
            "新版",
            "功能",
            "多功能",
            "高跟鞋",
            "鞋",
            "衣服",
            "裤",
            "裙",
            "包",
            "手机",
            "电脑",
            "家具",
            "洗面奶",
            "化妆水",
            "发酵",
            "导入",
        ),
        english_seeds=(
            "product",
            "goods",
            "details",
            "specification",
            "color",
            "size",
            "material",
            "stock",
            "in stock",
            "counter",
            "edition",
            "version",
            "function",
            "multifunctional",
            "shoe",
            "shoes",
            "clothes",
            "pants",
            "skirt",
            "bag",
            "phone",
            "computer",
            "furniture",
            "lotion",
            "toner",
            "cleansing",
            "ferment",
            "cosmetics",
        ),
    ),
    Category(
        name="general_terms",
        chinese_seeds=(
            "查看",
            "选择",
            "输入",
            "修改",
            "添加",
            "移除",
            "更新",
            "帮助",
            "客服",
            "联系",
            "详情",
            "通知",
            "提醒",
            "开始",
            "停止",
            "问题",
            "原因",
            "结果",
        ),
        english_seeds=(
            "view",
            "select",
            "input",
            "modify",
            "add",
            "remove",
            "update",
            "help",
            "customer service",
            "contact",
            "details",
            "notification",
            "reminder",
            "start",
            "stop",
            "problem",
            "reason",
            "result",
        ),
    ),
]

BLOCKLIST = {
    "的",
    "了",
    "在",
    "是",
    "有",
    "和",
    "与",
    "及",
    "或",
    "不",
    "就",
    "都",
    "很",
    "也",
    "又",
    "被",
    "把",
    "吧",
    "呢",
    "啊",
    "点",
}

SINGLE_CHARACTER_ALLOWLIST = {
    "年",
    "月",
    "日",
    "天",
    "周",
    "元",
    "件",
}

NOISY_RAW_FRAGMENTS = [
    "(archaic)",
    "(bound form)",
    "(classical)",
    "(dialect)",
    "(literary)",
    "abbr. for",
    "archaic",
    "classifier",
    "dialect",
    "grammatical particle",
    "interjection",
    "modal particle",
    "onomatopoeia",
    "phonetic",
    "radical",
    "see also",
    "variant of",
]

DISPLAY_OVERRIDES = {
    "打开": "open",
    "关闭": "close",
    "返回": "back",
    "确认": "confirm",
    "取消": "cancel",
    "保存": "save",
    "删除": "delete",
    "编辑": "edit",
    "复制": "copy",
    "粘贴": "paste",
    "分享": "share",
    "搜索": "search",
    "设置": "settings",
    "更多": "more",
    "全部": "all",
    "完成": "done",
    "继续": "continue",
    "跳过": "skip",
    "登录": "log in",
    "注册": "sign up",
    "账号": "account",
    "帐号": "account",
    "密码": "password",
    "验证码": "code",
    "手机号": "phone number",
    "邮箱": "email",
    "退出登录": "log out",
    "忘记密码": "forgot password",
    "成功": "success",
    "失败": "failed",
    "错误": "error",
    "加载中": "loading",
    "请稍后": "please wait",
    "稍后": "please wait",
    "暂无": "none yet",
    "网络错误": "network error",
    "重试": "retry",
    "权限": "permission",
    "允许": "allow",
    "拒绝": "deny",
    "消息": "messages",
    "对方": "other person",
    "正在": "in progress",
    "发送": "send",
    "接收": "receive",
    "已读": "read",
    "未读": "unread",
    "联系人": "contacts",
    "群聊": "group chat",
    "语音": "voice",
    "图片": "image",
    "视频": "video",
    "文件": "file",
    "位置": "location",
    "支付": "pay",
    "付款": "pay",
    "订单": "order",
    "退款": "refund",
    "购物车": "cart",
    "优惠券": "coupon",
    "发货": "send goods",
    "收货": "receive goods",
    "地址": "address",
    "快递": "express delivery",
    "物流": "logistics",
    "价格": "price",
    "数量": "quantity",
    "商品": "product",
    "产品": "product",
    "详情": "details",
    "规格": "specs",
    "颜色": "color",
    "尺寸": "size",
    "尺码": "size",
    "材质": "material",
    "材料": "material",
    "库存": "stock",
    "现货": "in stock",
    "专柜": "counter",
    "新版": "new version",
    "功能": "function",
    "多功能": "multifunctional",
    "运输": "transport",
    "包装": "packaging",
    "仓库": "warehouse",
    "标签": "label",
    "货物": "goods",
    "箱子": "box",
    "外箱": "outer box",
    "木架": "wooden crate",
    "入仓费": "warehouse fee",
    "私人仓": "private warehouse",
    "国际运输": "intl shipping",
    "明显标签": "clear label",
    "贴上": "stick on",
    "包装费": "packaging fee",
    "出口": "exit/export",
    "加收": "extra charge",
    "新版洗面奶": "cleansing lotion",
    "运费": "shipping fee",
    "包裹": "package",
    "配送": "delivery",
    "姓名": "name",
    "电话": "phone",
    "身份证": "ID card",
    "生日": "birthday",
    "性别": "gender",
    "国家": "country",
    "城市": "city",
    "地区": "region",
    "公司": "company",
    "学校": "school",
    "今天": "today",
    "明天": "tomorrow",
    "昨天": "yesterday",
    "时间": "time",
    "日期": "date",
    "小时": "hour",
    "分钟": "minute",
    "到期": "expires",
    "剩余": "remaining",
    "地图": "map",
    "路线": "route",
    "附近": "nearby",
    "距离": "distance",
    "目的地": "destination",
    "出发": "depart",
    "到达": "arrive",
    "公交": "bus",
    "地铁": "subway",
    "打车": "taxi",
    "外卖": "takeout",
    "餐厅": "restaurant",
    "菜单": "menu",
    "评价": "reviews",
    "预约": "appointment",
    "排队": "queue",
    "查看": "view",
    "导入": "import",
    "发酵": "ferment",
    "洗面奶": "cleansing lotion",
    "化妆水": "skin toner",
    "高跟鞋": "high-heeled shoes",
}


@dataclass(frozen=True)
class SourceEntry:
    simplified: str
    traditional: str
    source_compact: str
    pinyin: str
    english_raw: str


@dataclass(frozen=True)
class SelectedEntry:
    simplified: str
    traditional: str
    source_compact: str
    pinyin: str
    english_raw: str
    english_display: str
    category: str
    source_kind: str
    license_source: str
    priority: int
    selection_reason: str


@dataclass
class Metrics:
    full_input_rows: int = 0
    general_output_rows: int = 0
    exact_seed_rows: int = 0
    selected_by_chinese_seed: int = 0
    selected_by_english_seed: int = 0
    phrase_override_rows: int = 0
    rejected_by_blocklist: int = 0
    rejected_by_noise_rules: int = 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Build a broad CC-CEDICT SQLite subset with compact English labels "
            "for general Quick Look overlay experiments."
        )
    )
    parser.add_argument(
        "--input",
        required=True,
        type=Path,
        help="Full CC-CEDICT SQLite DB generated by convert_cc_cedict_sample.py.",
    )
    parser.add_argument(
        "--output",
        required=True,
        type=Path,
        help="General subset SQLite output path, preferably under /tmp.",
    )
    parser.add_argument(
        "--json-output",
        type=Path,
        help="Optional JSON output path for inspecting selected entries.",
    )
    parser.add_argument(
        "--max-display-length",
        type=int,
        default=DEFAULT_MAX_DISPLAY_LENGTH,
        help="Preferred maximum length for compact English overlay labels.",
    )
    parser.add_argument(
        "--max-raw-length",
        type=int,
        default=220,
        help="Reject non-exact entries with raw definitions longer than this.",
    )
    parser.add_argument(
        "--max-definition-count",
        type=int,
        default=6,
        help="Reject non-exact entries with more semicolon-separated senses.",
    )
    return parser.parse_args()


def normalized_source(text: str) -> str:
    normalized = unicodedata.normalize("NFKC", text or "")
    invisible = {
        "\u200b",
        "\u200c",
        "\u200d",
        "\u2060",
        "\ufeff",
    }
    return "".join(
        character
        for character in normalized
        if character not in invisible and not character.isspace()
    )


def phrase_key(text: str) -> str:
    return re.sub(r"[,.。！？!?:：；;、\s]+", "", normalized_source(text))


def normalized_words(text: str) -> str:
    return re.sub(r"\s+", " ", text.lower()).strip()


def load_entries(input_path: Path) -> list[SourceEntry]:
    connection = sqlite3.connect(input_path)
    connection.row_factory = sqlite3.Row

    try:
        rows = connection.execute(
            """
            SELECT simplified, traditional, sourceCompact, pinyin, english
            FROM entries
            ORDER BY id
            """
        ).fetchall()
    finally:
        connection.close()

    return [
        SourceEntry(
            simplified=row["simplified"],
            traditional=row["traditional"],
            source_compact=row["sourceCompact"],
            pinyin=row["pinyin"],
            english_raw=row["english"],
        )
        for row in rows
    ]


def entry_terms(entry: SourceEntry) -> set[str]:
    return {
        normalized_source(entry.simplified),
        normalized_source(entry.traditional),
        normalized_source(entry.source_compact),
    }


def category_matches(entry: SourceEntry) -> list[tuple[Category, list[str], list[str], bool]]:
    terms = entry_terms(entry)
    english = normalized_words(entry.english_raw)
    matches: list[tuple[Category, list[str], list[str], bool]] = []

    for category in CATEGORIES:
        chinese_matches = matching_chinese_seeds(terms, category.chinese_seeds)
        english_matches = matching_english_seeds(english, category.english_seeds)
        exact_seed = any(seed in terms for seed in category.chinese_seeds)

        if chinese_matches or english_matches or exact_seed:
            matches.append((category, chinese_matches, english_matches, exact_seed))

    return matches


def matching_chinese_seeds(terms: set[str], seeds: tuple[str, ...]) -> list[str]:
    matches: list[str] = []

    for seed in seeds:
        normalized_seed = normalized_source(seed)

        if any(
            normalized_seed in term or term in normalized_seed
            for term in terms
            if term
        ):
            matches.append(seed)

    return sorted(set(matches), key=lambda item: (-len(item), item))


def matching_english_seeds(english: str, seeds: tuple[str, ...]) -> list[str]:
    matches: list[str] = []

    for seed in seeds:
        pattern = r"(?<![a-z])" + re.escape(seed.lower()) + r"(?![a-z])"

        if re.search(pattern, english):
            matches.append(seed)

    return sorted(set(matches))


def choose_category(
    matches: list[tuple[Category, list[str], list[str], bool]],
) -> tuple[Category, list[str], list[str], bool]:
    return max(
        matches,
        key=lambda item: (
            item[3],
            len(item[1]) * 3 + len(item[2]),
            max((len(seed) for seed in item[1]), default=0),
            item[0].name,
        ),
    )


def is_blocklisted(entry: SourceEntry) -> bool:
    return any(term in BLOCKLIST for term in entry_terms(entry))


def is_single_character_noise(entry: SourceEntry) -> bool:
    source = normalized_source(entry.source_compact or entry.simplified)
    return len(source) == 1 and source not in SINGLE_CHARACTER_ALLOWLIST


def definition_count(raw: str) -> int:
    return len([part for part in raw.split(";") if part.strip()])


def is_noisy_raw(raw: str) -> bool:
    lowercased = raw.lower()
    return any(fragment in lowercased for fragment in NOISY_RAW_FRAGMENTS)


def split_definitions(raw: str) -> list[str]:
    parts = re.split(r";|/", raw)
    return [part.strip() for part in parts if part.strip()]


def clean_display_candidate(candidate: str) -> str:
    cleaned = re.sub(r"CL:[^;]+", "", candidate)
    cleaned = re.sub(r"\([^)]*\)", "", cleaned)
    cleaned = re.sub(r"\[[^\]]*\]", "", cleaned)
    cleaned = cleaned.replace("sb or sth", "").replace("sb", "").replace("sth", "")
    cleaned = cleaned.replace("etc", "")
    cleaned = re.sub(r"\s+", " ", cleaned)
    cleaned = cleaned.strip(" ,.;:-")

    if cleaned.startswith("to "):
        cleaned = cleaned[3:]

    replacements = {
        "send out goods": "send goods",
        "dispatch": "send",
        "provide a takeout or home delivery meal": "takeout delivery",
        "takeout business": "takeout",
        "takeout meal": "takeout",
        "telephone number": "phone number",
        "cell phone number": "phone number",
        "merchandise or commodities available immediately after sale": "in stock",
        "depot": "warehouse",
        "storehouse": "warehouse",
        "to refund": "refund",
        "refund": "refund",
    }

    return replacements.get(cleaned.lower(), cleaned)


def is_bad_display(display: str) -> bool:
    if not display:
        return True

    lowercased = display.lower()
    bad_fragments = [
        "variant of",
        "surname",
        "classifier",
        "literary",
        "dialect",
        "radical",
        "particle",
        "abbr.",
        "see ",
    ]
    return any(fragment in lowercased for fragment in bad_fragments)


def compact_english_display(
    entry: SourceEntry,
    category: Category,
    max_display_length: int,
) -> str | None:
    for term in entry_terms(entry):
        override = DISPLAY_OVERRIDES.get(term)

        if override:
            return override

    candidates: list[str] = []

    for part in split_definitions(entry.english_raw):
        cleaned = clean_display_candidate(part)

        if cleaned and not is_bad_display(cleaned):
            candidates.append(cleaned)

    if not candidates:
        return None

    category_keywords = set(category.english_seeds)

    def candidate_score(candidate: str) -> tuple[int, int, int, str]:
        lowercased = candidate.lower()
        contains_keyword = any(keyword in lowercased for keyword in category_keywords)
        within_limit = len(candidate) <= max_display_length
        starts_to = lowercased.startswith("to ")
        return (
            1 if contains_keyword else 0,
            1 if within_limit else 0,
            0 if starts_to else 1,
            candidate,
        )

    viable = [
        candidate
        for candidate in candidates
        if len(candidate) <= max_display_length and not is_bad_display(candidate)
    ]

    if viable:
        return min(
            viable,
            key=lambda candidate: (
                -candidate_score(candidate)[0],
                len(candidate),
                candidate,
            ),
        )

    best = max(candidates, key=candidate_score)

    if len(best) <= max_display_length + 8:
        return best

    return None


def select_entry(
    entry: SourceEntry,
    metrics: Metrics,
    max_display_length: int,
    max_raw_length: int,
    max_definition_count: int,
) -> SelectedEntry | None:
    if is_blocklisted(entry):
        metrics.rejected_by_blocklist += 1
        return None

    matches = category_matches(entry)

    if not matches:
        return None

    category, chinese_matches, english_matches, exact_seed = choose_category(matches)

    if is_single_character_noise(entry):
        metrics.rejected_by_noise_rules += 1
        return None

    if not exact_seed:
        if len(entry.english_raw) > max_raw_length:
            metrics.rejected_by_noise_rules += 1
            return None

        if definition_count(entry.english_raw) > max_definition_count:
            metrics.rejected_by_noise_rules += 1
            return None

        if is_noisy_raw(entry.english_raw):
            metrics.rejected_by_noise_rules += 1
            return None

    display = compact_english_display(entry, category, max_display_length)

    if display is None:
        metrics.rejected_by_noise_rules += 1
        return None

    source_length = len(normalized_source(entry.source_compact or entry.simplified))

    if source_length > 8 and not exact_seed and len(display) > max_display_length:
        metrics.rejected_by_noise_rules += 1
        return None

    if exact_seed:
        metrics.exact_seed_rows += 1

    if chinese_matches:
        metrics.selected_by_chinese_seed += 1

    if english_matches:
        metrics.selected_by_english_seed += 1

    priority = 0
    priority += 100 if exact_seed else 0
    priority += 45 if chinese_matches else 0
    priority += 25 if english_matches else 0
    priority += min(24, source_length * 3)
    priority += max(0, max_display_length - len(display)) // 2
    priority -= min(15, max(0, definition_count(entry.english_raw) - 1) * 3)

    reasons: list[str] = []

    if exact_seed:
        reasons.append("exactSeed")

    if chinese_matches:
        reasons.append("chinese:" + "|".join(chinese_matches[:3]))

    if english_matches:
        reasons.append("english:" + "|".join(english_matches[:3]))

    return SelectedEntry(
        simplified=entry.simplified,
        traditional=entry.traditional,
        source_compact=entry.source_compact,
        pinyin=entry.pinyin,
        english_raw=entry.english_raw,
        english_display=display,
        category=category.name,
        source_kind="cc_cedict",
        license_source=LICENSE_SOURCE,
        priority=priority,
        selection_reason=", ".join(reasons),
    )


def add_phrase_override_rows(
    entries: list[SelectedEntry],
    metrics: Metrics,
) -> list[SelectedEntry]:
    by_key = {
        normalized_source(entry.source_compact or entry.simplified): entry
        for entry in entries
    }

    for phrase, label in PHRASE_DISPLAY_OVERRIDES.items():
        key = phrase_key(phrase)
        existing = by_key.get(key)
        priority = 240

        if existing is not None:
            priority = max(priority, existing.priority + 20)

        by_key[key] = SelectedEntry(
            simplified=phrase,
            traditional=phrase,
            source_compact=key,
            pinyin=existing.pinyin if existing else "",
            english_raw=existing.english_raw if existing else label,
            english_display=label,
            category=category_for_phrase(phrase),
            source_kind="app_phrase_override",
            license_source=APP_OVERRIDE_SOURCE,
            priority=priority,
            selection_reason="phraseOverride",
        )
        metrics.phrase_override_rows += 1

    return list(by_key.values())


def category_for_phrase(phrase: str) -> str:
    key = phrase_key(phrase)

    if any(term in key for term in ["登录", "验证码", "手机号", "绑定", "解绑"]):
        return "accounts_login"

    if any(term in key for term in ["错误", "权限", "过期", "不支持", "暂无", "加载", "稍后", "连接"]):
        return "status_errors"

    if any(term in key for term in ["输入", "消息", "图片", "链接", "文件"]):
        return "chat_messages"

    if any(term in key for term in ["支付", "退款", "订单", "快递", "物流"]):
        return "payment_order_shopping"

    if any(term in key for term in ["外箱", "木架", "入仓", "仓", "运输", "标签", "包装", "出口", "加收"]):
        return "delivery_logistics"

    if any(term in key for term in ["地铁", "位置", "附近"]):
        return "navigation_location"

    if any(term in key for term in ["餐厅", "预约"]):
        return "food_services"

    if any(term in key for term in ["洗面奶", "化妆水", "商品", "产品", "现货", "专柜", "高跟鞋"]):
        return "product_details"

    return "common_app_ui"


def create_database(output_path: Path, entries: list[SelectedEntry]) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    if output_path.exists():
        output_path.unlink()

    connection = sqlite3.connect(output_path)

    try:
        connection.executescript(
            """
            CREATE TABLE entries (
                id INTEGER PRIMARY KEY,
                simplified TEXT,
                traditional TEXT,
                sourceCompact TEXT,
                pinyin TEXT,
                englishRaw TEXT,
                englishDisplay TEXT,
                category TEXT,
                sourceKind TEXT DEFAULT 'cc_cedict',
                licenseSource TEXT DEFAULT 'CC-CEDICT CC BY-SA 4.0',
                priority INTEGER,
                selectionReason TEXT
            );

            CREATE INDEX idx_entries_simplified ON entries(simplified);
            CREATE INDEX idx_entries_traditional ON entries(traditional);
            CREATE INDEX idx_entries_sourceCompact ON entries(sourceCompact);
            CREATE INDEX idx_entries_category ON entries(category);
            CREATE INDEX idx_entries_priority ON entries(priority);
            """
        )
        connection.executemany(
            """
            INSERT INTO entries (
                simplified,
                traditional,
                sourceCompact,
                pinyin,
                englishRaw,
                englishDisplay,
                category,
                sourceKind,
                licenseSource,
                priority,
                selectionReason
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    entry.simplified,
                    entry.traditional,
                    entry.source_compact,
                    entry.pinyin,
                    entry.english_raw,
                    entry.english_display,
                    entry.category,
                    entry.source_kind,
                    entry.license_source,
                    entry.priority,
                    entry.selection_reason,
                )
                for entry in entries
            ],
        )
        connection.commit()
    finally:
        connection.close()


def write_json(output_path: Path, entries: list[SelectedEntry]) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(
            [
                {
                    **asdict(entry),
                    "sourceKind": entry.source_kind,
                    "licenseSource": entry.license_source,
                }
                for entry in entries
            ],
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )


def print_metrics(input_path: Path, output_path: Path, entries: list[SelectedEntry], metrics: Metrics) -> None:
    output_size = output_path.stat().st_size if output_path.exists() else 0
    category_counts: dict[str, int] = {}

    for entry in entries:
        category_counts[entry.category] = category_counts.get(entry.category, 0) + 1

    print(f"Input: {input_path}")
    print(f"Output: {output_path}")
    print(f"Full input rows: {metrics.full_input_rows}")
    print(f"General output rows: {metrics.general_output_rows}")
    print(f"Output SQLite bytes: {output_size}")
    print(f"Exact seed rows: {metrics.exact_seed_rows}")
    print(f"Selected by Chinese seed: {metrics.selected_by_chinese_seed}")
    print(f"Selected by English seed: {metrics.selected_by_english_seed}")
    print(f"Phrase override rows: {metrics.phrase_override_rows}")
    print(f"Rejected by blocklist: {metrics.rejected_by_blocklist}")
    print(f"Rejected by noise rules: {metrics.rejected_by_noise_rules}")
    print("Category rows:")

    for category, count in sorted(category_counts.items()):
        print(f"  {category}: {count}")


def main() -> int:
    args = parse_args()

    if not args.input.is_file():
        print(f"Input DB not found: {args.input}", file=sys.stderr)
        return 2

    source_entries = load_entries(args.input)
    metrics = Metrics(full_input_rows=len(source_entries))
    selected: list[SelectedEntry] = []

    for source_entry in source_entries:
        selected_entry = select_entry(
            source_entry,
            metrics,
            max_display_length=args.max_display_length,
            max_raw_length=args.max_raw_length,
            max_definition_count=args.max_definition_count,
        )

        if selected_entry is not None:
            selected.append(selected_entry)

    selected = add_phrase_override_rows(selected, metrics)
    selected.sort(
        key=lambda entry: (
            -entry.priority,
            entry.category,
            -len(normalized_source(entry.source_compact or entry.simplified)),
            entry.simplified,
        )
    )
    metrics.general_output_rows = len(selected)

    create_database(args.output, selected)

    if args.json_output is not None:
        write_json(args.json_output, selected)

    print_metrics(args.input, args.output, selected, metrics)

    if args.json_output is not None:
        print(f"JSON output: {args.json_output}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
