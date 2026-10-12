--[[
  docx2md.lua — Word(.docx) 문서를 Hugo용 Markdown으로 바꿀 때 쓰는 pandoc 필터

  하는 일
  1. 형광펜(하이라이트)            → <mark>…</mark>
  2. 제목(Heading) 안의 굵게 표시  → 제거(제목은 원래 굵게 보임), 빈 제목 삭제
  3. 문서가 '제목 1'부터 쓰면      → 한 단계씩 내림(사이트에서는 글 제목이 '제목 1'이므로)
  4. 칸이 하나뿐인 표(박스)        → 강조 상자(callout)
  5. 'flowchart LR …' 같은 글      → Mermaid 다이어그램
  6. 굵게/기울임이 한국어 조사와 붙어 깨지는 경우 → HTML 태그로 안전하게 출력
  7. 글 제목 판단: 문서 첫 줄이 제목이면 그것을, 아니면 파일 이름을 사용
]]

local MERMAID_START = {
  "flowchart", "graph", "sequenceDiagram", "classDiagram", "stateDiagram",
  "erDiagram", "gantt", "pie", "mindmap", "timeline", "journey",
}

-- 줄바꿈을 살려서 인라인 요소를 글자로 바꾼다
local function to_text(inlines)
  local out = {}
  local function walk(list)
    for _, el in ipairs(list) do
      local t = el.t
      if t == "Str" then table.insert(out, el.text)
      elseif t == "Space" then table.insert(out, " ")
      elseif t == "SoftBreak" or t == "LineBreak" then table.insert(out, "\n")
      elseif t == "Code" or t == "RawInline" then table.insert(out, el.text)
      elseif t == "Quoted" then
        local q = el.quotetype == "SingleQuote" and "'" or '"'
        table.insert(out, q); walk(el.content); table.insert(out, q)
      elseif el.content then walk(el.content)
      end
    end
  end
  walk(inlines)
  return table.concat(out)
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function mermaid_block(text)
  local first = text:match("^%s*([%a]+)")
  if not first then return nil end
  for _, kw in ipairs(MERMAID_START) do
    if first == kw then
      -- 줄마다 앞뒤 공백 정리, 빈 줄 제거
      local lines = {}
      for line in (text .. "\n"):gmatch("(.-)\n") do
        line = trim(line)
        if line ~= "" then table.insert(lines, (#lines == 0) and line or ("    " .. line)) end
      end
      return pandoc.CodeBlock(table.concat(lines, "\n"), { class = "mermaid" })
    end
  end
  return nil
end

------------------------------------------------------------------------
-- 1단계: 형광펜, Mermaid, 박스
------------------------------------------------------------------------
local pass1 = {
  Span = function(el)
    if el.classes:includes("mark") then
      local res = { pandoc.RawInline("html", "<mark>") }
      for _, x in ipairs(el.content) do table.insert(res, x) end
      table.insert(res, pandoc.RawInline("html", "</mark>"))
      return res
    end
    -- 그 밖의 서식용 span(밑줄 등)은 내용만 남긴다
    if #el.classes > 0 and not el.classes:includes("underline") then
      return el.content
    end
  end,

  Underline = function(el) return el.content end,

  Para = function(el)
    local cb = mermaid_block(to_text(el.content))
    if cb then return cb end
  end,

  Table = function(tbl)
    -- 칸이 정확히 하나인 표 → 강조 상자
    local cells = {}
    for _, row in ipairs(tbl.head.rows) do
      for _, c in ipairs(row.cells) do table.insert(cells, c) end
    end
    for _, body in ipairs(tbl.bodies) do
      for _, row in ipairs(body.body) do
        for _, c in ipairs(row.cells) do table.insert(cells, c) end
      end
    end
    for _, row in ipairs(tbl.foot.rows) do
      for _, c in ipairs(row.cells) do table.insert(cells, c) end
    end
    if #cells ~= 1 then return nil end

    local blocks = cells[1].contents
    local out = {}
    local first = blocks[1]
    local start = 1
    -- 첫 문단이 통째로 굵은 글씨라면 상자의 제목으로 쓴다
    if first and (first.t == "Para" or first.t == "Plain") and #first.content == 1
       and first.content[1].t == "Strong" then
      table.insert(out, pandoc.Div({ pandoc.Plain(first.content[1].content) }, { class = "callout-title" }))
      start = 2
    end
    for i = start, #blocks do table.insert(out, blocks[i]) end
    return pandoc.Div(out, { class = "callout" })
  end,
}

------------------------------------------------------------------------
-- 2단계: 굵게/기울임을 안전하게
--   CommonMark 규칙상 '**…)**이라는'처럼 강조가 문장부호로 끝나고 바로 한글이
--   붙으면 굵게가 풀린다. 그런 경우만 <strong> 태그로 바꾼다.
------------------------------------------------------------------------
local function is_punct_char(c)
  if c == nil or c == "" then return false end
  return c:match("^[%p]$") ~= nil
end

local function edge_char(inlines, at_end)
  local el = at_end and inlines[#inlines] or inlines[1]
  if not el then return nil end
  if el.t == "RawInline" then return "<" end         -- <mark> 등
  if el.t == "Str" then
    local s = el.text
    if s == "" then return nil end
    if at_end then
      -- UTF-8 마지막 글자
      local last = s:match("[%z\1-\127\194-\244][\128-\191]*$")
      return last
    else
      return s:match("^[%z\1-\127\194-\244][\128-\191]*")
    end
  end
  if el.content then return edge_char(el.content, at_end) end
  if el.t == "Quoted" then return '"' end
  return nil
end

local function needs_html(el)
  local a, b = edge_char(el.content, false), edge_char(el.content, true)
  -- ASCII 문장부호뿐 아니라 따옴표·괄호 같은 전각 부호도 문제를 일으킨다
  local function risky(c)
    if not c then return false end
    if is_punct_char(c) then return true end
    if c == "·" or c == "…" or c == "※" then return true end
    return c:match("^[\226\227\239]") ~= nil and not c:match("^[\234-\237]")
  end
  return risky(a) or risky(b)
end

local function wrap(tag, el)
  local res = { pandoc.RawInline("html", "<" .. tag .. ">") }
  for _, x in ipairs(el.content) do table.insert(res, x) end
  table.insert(res, pandoc.RawInline("html", "</" .. tag .. ">"))
  return res
end

local pass2 = {
  Strong = function(el) if needs_html(el) then return wrap("strong", el) end end,
  Emph   = function(el) if needs_html(el) then return wrap("em", el) end end,
}

------------------------------------------------------------------------
-- 3단계: 제목 정리, 글 제목 추출
------------------------------------------------------------------------
local function clean_header_text(h)
  local s = trim(pandoc.utils.stringify(h.content))
  return s
end

local pass3 = {
  Pandoc = function(doc)
    local blocks = doc.blocks
    local fntitle = doc.meta.fntitle and pandoc.utils.stringify(doc.meta.fntitle) or ""

    -- 빈 제목 삭제, 제목 안 서식 제거
    local cleaned = {}
    for _, b in ipairs(blocks) do
      if b.t == "Header" then
        local s = clean_header_text(b)
        if s ~= "" then
          table.insert(cleaned, pandoc.Header(b.level, pandoc.Inlines(s), b.attr))
        end
      else
        table.insert(cleaned, b)
      end
    end
    blocks = cleaned

    -- 문서 맨 앞의 빈 문단 제거
    while #blocks > 0 and (blocks[1].t == "Para" or blocks[1].t == "Plain")
          and trim(pandoc.utils.stringify(blocks[1])) == "" do
      table.remove(blocks, 1)
    end

    -- 글 제목: 문서가 제목(Heading)으로 시작하면 그것을 쓰고 본문에서 뺀다
    local title = ""
    if #blocks > 0 and blocks[1].t == "Header" then
      title = pandoc.utils.stringify(blocks[1].content)
      table.remove(blocks, 1)
    else
      title = fntitle
      -- 문서 앞부분(첫 제목 전)에 파일 이름과 같은 문단이 있으면 중복이므로 뺀다
      for i = 1, math.min(6, #blocks) do
        local b = blocks[i]
        if b.t == "Header" then break end
        if (b.t == "Para" or b.t == "Plain") then
          local s = trim(pandoc.utils.stringify(b))
          if s ~= "" and s:gsub("%s", "") == title:gsub("%s", "") then
            table.remove(blocks, i)
            break
          end
        end
      end
    end

    -- 가장 높은 제목이 '제목 1'이면 전부 한 단계 내림
    local minlevel = 9
    for _, b in ipairs(blocks) do
      if b.t == "Header" and b.level < minlevel then minlevel = b.level end
    end
    if minlevel == 1 then
      for i, b in ipairs(blocks) do
        if b.t == "Header" then b.level = math.min(b.level + 1, 6); blocks[i] = b end
      end
    end

    doc.blocks = blocks
    doc.meta.autotitle = title
    return doc
  end,
}

return { pass1, pass2, pass3 }
