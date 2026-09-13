from pathlib import Path

from docx import Document
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


OUTPUT = Path(r"C:\Users\xu\Desktop\毕设and比赛\HelpShop项目进展报告_2026-07-10.docx")


BLUE = RGBColor(46, 116, 181)
DARK_BLUE = RGBColor(31, 77, 120)
INK = RGBColor(36, 26, 20)
MUTED = RGBColor(89, 89, 89)
LIGHT_FILL = "F2F4F7"
ACCENT_FILL = "F6EDE7"
BORDER = "D9E2F3"


def set_run_font(run, size=None, bold=None, color=None, font="Microsoft YaHei"):
    run.font.name = font
    run._element.rPr.rFonts.set(qn("w:ascii"), font)
    run._element.rPr.rFonts.set(qn("w:hAnsi"), font)
    run._element.rPr.rFonts.set(qn("w:eastAsia"), font)
    if size is not None:
        run.font.size = Pt(size)
    if bold is not None:
        run.bold = bold
    if color is not None:
        run.font.color.rgb = color


def set_paragraph_spacing(paragraph, before=0, after=6, line=1.1):
    fmt = paragraph.paragraph_format
    fmt.space_before = Pt(before)
    fmt.space_after = Pt(after)
    fmt.line_spacing = line


def set_cell_shading(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_border(cell, color="D9D9D9"):
    tc_pr = cell._tc.get_or_add_tcPr()
    borders = tc_pr.first_child_found_in("w:tcBorders")
    if borders is None:
        borders = OxmlElement("w:tcBorders")
        tc_pr.append(borders)
    for edge in ("top", "left", "bottom", "right"):
        tag = "w:" + edge
        element = borders.find(qn(tag))
        if element is None:
            element = OxmlElement(tag)
            borders.append(element)
        element.set(qn("w:val"), "single")
        element.set(qn("w:sz"), "6")
        element.set(qn("w:space"), "0")
        element.set(qn("w:color"), color)


def set_cell_margins(cell, top=80, start=120, bottom=80, end=120):
    tc_pr = cell._tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for m, v in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = tc_mar.find(qn(f"w:{m}"))
        if node is None:
            node = OxmlElement(f"w:{m}")
            tc_mar.append(node)
        node.set(qn("w:w"), str(v))
        node.set(qn("w:type"), "dxa")


def set_table_width(table, widths):
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    for row in table.rows:
        for idx, width in enumerate(widths):
            cell = row.cells[idx]
            cell.width = Inches(width)
            tc_pr = cell._tc.get_or_add_tcPr()
            tc_w = tc_pr.first_child_found_in("w:tcW")
            if tc_w is None:
                tc_w = OxmlElement("w:tcW")
                tc_pr.append(tc_w)
            tc_w.set(qn("w:w"), str(int(width * 1440)))
            tc_w.set(qn("w:type"), "dxa")
            set_cell_margins(cell)
            set_cell_border(cell, BORDER)


def add_title(doc):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    set_paragraph_spacing(p, before=12, after=4, line=1.1)
    run = p.add_run("HelpShop 项目进展报告")
    set_run_font(run, size=24, bold=True, color=INK)

    p = doc.add_paragraph()
    set_paragraph_spacing(p, before=0, after=14, line=1.1)
    run = p.add_run("日期：2026年7月10日    项目：老人网购助手 HelpShop")
    set_run_font(run, size=11, color=MUTED)

    table = doc.add_table(rows=4, cols=2)
    set_table_width(table, [1.45, 5.05])
    rows = [
        ("当前阶段", "P0 演示闭环完善与真实后端接入"),
        ("今日重点", "前端商城体验、身份认证绑定、后端接口、前后端数据对接"),
        ("构建状态", "HarmonyOS entry 模块 assembleHap 构建通过"),
        ("后端状态", "FastAPI + SQLite 已支撑登录、认证、绑定、地址、订单、提醒、模拟支付"),
    ]
    for idx, (label, value) in enumerate(rows):
        cells = table.rows[idx].cells
        set_cell_shading(cells[0], LIGHT_FILL)
        for cell in cells:
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        rp = cells[0].paragraphs[0]
        set_paragraph_spacing(rp, after=0)
        rr = rp.add_run(label)
        set_run_font(rr, size=10.5, bold=True, color=DARK_BLUE)
        vp = cells[1].paragraphs[0]
        set_paragraph_spacing(vp, after=0)
        vr = vp.add_run(value)
        set_run_font(vr, size=10.5, color=INK)


def heading(doc, text, level=1):
    p = doc.add_paragraph()
    before = 16 if level == 1 else 10
    after = 7 if level == 1 else 5
    set_paragraph_spacing(p, before=before, after=after, line=1.1)
    run = p.add_run(text)
    set_run_font(run, size=16 if level == 1 else 13, bold=True, color=BLUE if level == 1 else DARK_BLUE)


def para(doc, text, bold_prefix=None):
    p = doc.add_paragraph()
    set_paragraph_spacing(p, after=6, line=1.1)
    if bold_prefix and text.startswith(bold_prefix):
        r1 = p.add_run(bold_prefix)
        set_run_font(r1, size=11, bold=True, color=INK)
        r2 = p.add_run(text[len(bold_prefix):])
        set_run_font(r2, size=11, color=INK)
    else:
        r = p.add_run(text)
        set_run_font(r, size=11, color=INK)


def bullet(doc, text):
    p = doc.add_paragraph(style="List Bullet")
    set_paragraph_spacing(p, after=4, line=1.1)
    p.paragraph_format.left_indent = Inches(0.25)
    p.paragraph_format.first_line_indent = Inches(-0.08)
    r = p.add_run(text)
    set_run_font(r, size=10.8, color=INK)


def add_status_table(doc):
    table = doc.add_table(rows=1, cols=4)
    set_table_width(table, [1.25, 2.35, 1.05, 1.85])
    headers = ["模块", "今日进展", "状态", "说明"]
    for i, h in enumerate(headers):
        cell = table.rows[0].cells[i]
        set_cell_shading(cell, LIGHT_FILL)
        p = cell.paragraphs[0]
        set_paragraph_spacing(p, after=0)
        r = p.add_run(h)
        set_run_font(r, size=10.5, bold=True, color=DARK_BLUE)
    data = [
        ("前端商城", "商品卡片、分类页、商品详情页优化", "完成", "更接近识货类商品发现体验，同时保留适老化按钮和字号"),
        ("商品图片", "本地演示图与 imageUrl 字段预留", "完成", "后续真实平台接口可直接映射真实图片 URL"),
        ("登录认证", "注册后未认证，应用内认证老人/子女", "完成", "前端已接入 /api/auth/certify"),
        ("家庭绑定", "子女绑定老人并同步本地会话", "完成", "未绑定时不能进入老人商城代买"),
        ("数据归属", "订单、地址、提醒按老人账号隔离", "完成", "子女代买订单额外记录代买人账号"),
        ("后端接口", "地址、订单、提醒、模拟支付接入 FastAPI", "完成", "前端优先远程，失败回退本地 Mock"),
        ("构建验证", "assembleHap 与后端接口回归", "通过", "仅保留未配置签名的正常警告"),
    ]
    for row_data in data:
        cells = table.add_row().cells
        for idx, value in enumerate(row_data):
            p = cells[idx].paragraphs[0]
            set_paragraph_spacing(p, after=0, line=1.05)
            r = p.add_run(value)
            set_run_font(r, size=9.5, bold=(idx == 0), color=INK)
            if idx == 2:
                p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            cells[idx].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER


def build_doc():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    doc = Document()
    section = doc.sections[0]
    section.top_margin = Inches(1)
    section.bottom_margin = Inches(1)
    section.left_margin = Inches(1)
    section.right_margin = Inches(1)

    normal = doc.styles["Normal"]
    normal.font.name = "Microsoft YaHei"
    normal._element.rPr.rFonts.set(qn("w:eastAsia"), "Microsoft YaHei")
    normal.font.size = Pt(11)

    header = section.header.paragraphs[0]
    header.text = "HelpShop 项目进展报告"
    header.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    set_paragraph_spacing(header, after=0)
    for run in header.runs:
        set_run_font(run, size=9, color=MUTED)

    footer = section.footer.paragraphs[0]
    footer.text = "P0 演示闭环与远程后端接入"
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    for run in footer.runs:
        set_run_font(run, size=9, color=MUTED)

    add_title(doc)

    heading(doc, "一、今日工作概览")
    para(doc, "今天主要围绕 HelpShop 的前端商城体验、身份认证绑定闭环、后端接口对接三个方向进行了完善。整体目标是让项目从本地 Mock 演示逐步过渡到可由 FastAPI + SQLite 支撑的真实后端演示闭环。")
    add_status_table(doc)

    heading(doc, "二、前端商城体验优化")
    bullet(doc, "推荐商品卡片已增加本地商品图片，并预留真实平台图片 URL 替换能力。")
    bullet(doc, "首页移除了“安心选购”冗余模块，常买需求区移除了手写引导按钮。")
    bullet(doc, "分类页商品支持点击进入详情页，不再只提供直接购买入口。")
    bullet(doc, "新增商品详情页，展示图片、平台、店铺、价格、评分、销量、标签和 Agent 选购建议。")
    bullet(doc, "整体继续保持橙黄与白色结合的暖色风格，同时控制饱和度，避免廉价感。")

    heading(doc, "三、身份认证与家庭绑定闭环")
    bullet(doc, "注册后账号默认进入未认证状态，登录后根据身份跳转到老人端、子女端或身份认证页。")
    bullet(doc, "新增后端身份认证接口 /api/auth/certify，前端 IdentityAuth 页面已接入。")
    bullet(doc, "完善子女绑定老人逻辑，后端接口 /api/family/bind 返回绑定关系和老人账号信息。")
    bullet(doc, "新增 /api/family/bindings，用于查询子女当前绑定的老人列表。")
    bullet(doc, "取消未绑定时自动回退到默认老人账号的逻辑，避免地址、订单、提醒数据串号。")

    heading(doc, "四、后端与数据归属完善")
    para(doc, "后端仍保持纯血鸿蒙 App 的边界：HarmonyOS entry 只承担前端和端侧服务封装，FastAPI 作为外部服务运行，不打包进 HAP。")
    bullet(doc, "FastAPI + SQLite 已支持登录、注册、身份认证、家庭绑定、地址管理、订单查询、提醒查询、模拟支付。")
    bullet(doc, "地址数据按老人账号隔离，子女绑定老人后才可维护对应老人地址。")
    bullet(doc, "老人自己购物时，订单归属老人账号；子女代买时，订单仍归属老人账号，并记录 managedByChildAccountId。")
    bullet(doc, "提醒记录按老人账号和绑定子女账号过滤，支付成功后生成子女端可见提醒。")
    bullet(doc, "订单查询接口已增强，返回前端渲染所需的商品、地址、支付和代买信息。")

    heading(doc, "五、前后端对接进展")
    bullet(doc, "地址管理页优先读写远程后端，后端不可用时回退本地 Mock。")
    bullet(doc, "支付确认页优先调用远程模拟支付接口，成功后订单和提醒写入 SQLite。")
    bullet(doc, "订单历史页优先读取远程订单列表。")
    bullet(doc, "提醒记录页优先读取远程提醒，并支持远程全部已读。")
    bullet(doc, "子女端首页统计优先读取远程地址和提醒数据。")
    bullet(doc, "AppConfig 已调整为 RemoteApi，当前后端地址为 http://192.168.80.1:8000。")

    heading(doc, "六、验证结果")
    bullet(doc, "后端语法检查通过：python -m py_compile backend/app.py。")
    bullet(doc, "FastAPI 接口回归通过：登录、认证、绑定、地址新增、设置默认、模拟支付、订单查询、提醒查询、全部已读、删除地址。")
    bullet(doc, "HarmonyOS entry 模块构建通过：assembleHap 显示 BUILD SUCCESSFUL。")
    bullet(doc, "当前仅存在未配置 HAP 签名的正常警告，不影响 DevEco 模拟器调试。")

    heading(doc, "七、当前项目状态")
    para(doc, "项目目前已经具备较完整的 P0 演示闭环：用户登录注册、应用内身份认证、老人端购物、子女端绑定老人、子女帮助老人购物、商品推荐与详情查看、地址管理、模拟支付、订单生成、子女提醒记录、后端 SQLite 数据持久化。")
    para(doc, "当前商品数据仍使用 Mock 数据和本地演示图片，暂未接入淘宝、京东、拼多多等真实购物平台官方接口。该部分后续可在已有 imageUrl、平台网关和适配器结构上继续替换。")

    heading(doc, "八、下一步建议")
    bullet(doc, "重启 FastAPI 后端服务，确保今日新增接口生效。")
    bullet(doc, "在 DevEco 模拟器完整测试：子女登录、绑定老人、新增地址、帮助购物、支付成功、查看订单、查看提醒。")
    bullet(doc, "继续完善真实后端错误提示、接口异常状态、Token 过期处理和登录态持久化。")
    bullet(doc, "后续再推进语音输入、真实分布式 KV、真实分布式通知、真实支付能力和真实购物平台图片/商品接口。")

    doc.save(OUTPUT)
    return OUTPUT


if __name__ == "__main__":
    print(build_doc())
