-- ============================================================
-- ksk.sqlite  最高裁判所規則リンク解決DB スキーマ
-- 配布物（rules.json / aliases.json / articles/NNN.json）から
-- sympos 側でビルドするローカルキャッシュ。
-- 既存の lawdb.sqlite（e-Gov法令）と同じ流儀で持つ。
-- ============================================================

PRAGMA journal_mode = WAL;

-- ------------------------------------------------------------
-- 規則マスタ
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rules (
    rule_id         TEXT PRIMARY KEY,   -- '100' 〜 '901'（3桁固定・永久ID）
    category        TEXT NOT NULL,      -- '民事訴訟' 等（先頭桁と対応）
    title           TEXT NOT NULL,      -- 正式名称
    title_norm      TEXT NOT NULL,      -- 正規化名称（照合用）
    law_number      TEXT,               -- 平成8年12月17日最高裁判所規則第5号
    era             TEXT,               -- 明治/大正/昭和/平成/令和
    era_year        INTEGER,            -- 8
    rule_no         INTEGER,            -- 5（最高裁判所規則第N号）
    enforcement_iso TEXT,               -- '2026-05-21'（不明はNULL）
    article_count   INTEGER NOT NULL,
    html            TEXT NOT NULL,      -- 'r/100.html'
    url             TEXT NOT NULL,      -- 絶対URL
    pdf_url         TEXT,               -- 裁判所サイトの原本PDF
    legacy_dir      TEXT,               -- 旧ローマ字フォルダ名（移行検証用）
    updated_at      TEXT
);
CREATE INDEX IF NOT EXISTS idx_rules_title_norm ON rules(title_norm);
CREATE INDEX IF NOT EXISTS idx_rules_lawno      ON rules(era, era_year, rule_no);

-- ------------------------------------------------------------
-- 別名（正式名称・略称・条文内定義・誤記ゆらぎ）
--   alias_norm は正規化済み。最長一致で引く。
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS aliases (
    alias_norm  TEXT NOT NULL,
    rule_id     TEXT NOT NULL REFERENCES rules(rule_id),
    alias       TEXT NOT NULL,      -- 表示用の原表記
    kind        TEXT NOT NULL,      -- '正式' | '略称' | '定義' | 'ゆらぎ'
    priority    INTEGER NOT NULL,   -- 小さいほど優先（正式=0, 略称=10）
    ambiguous   INTEGER NOT NULL DEFAULT 0,  -- 1なら単独ヒットでリンクしない
    PRIMARY KEY (alias_norm, rule_id)
);
CREATE INDEX IF NOT EXISTS idx_aliases_len ON aliases(length(alias_norm) DESC);

-- ------------------------------------------------------------
-- 条（アンカー解決の実体）
--   art_key: 本則 '105_2'（第105条の2）/ 附則 's1:3'（附則1本目の第3条）
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS articles (
    rule_id     TEXT NOT NULL REFERENCES rules(rule_id),
    art_key     TEXT NOT NULL,
    section     TEXT NOT NULL,      -- 'main' | 'supplementary'
    sup_index   INTEGER NOT NULL DEFAULT 0,
    art_no      INTEGER,            -- 105
    branch      TEXT,               -- '2'（枝番、なければNULL）
    label       TEXT NOT NULL,      -- '第百五条の二'
    short_label TEXT NOT NULL,      -- '105条の2'
    caption     TEXT,               -- 条見出し（ツールチップ用）
    anchor      TEXT NOT NULL,      -- 'a105-2'
    para_count  INTEGER NOT NULL DEFAULT 0,
    deleted     INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (rule_id, section, sup_index, art_key)
);
CREATE INDEX IF NOT EXISTS idx_articles_lookup ON articles(rule_id, art_no, branch);

-- ------------------------------------------------------------
-- 引用箇所の完全なアンカーを組み立てるビュー
--   例: 民訴規105条の2第1項 → r/100.html#a105-2-p1
-- ------------------------------------------------------------
CREATE VIEW IF NOT EXISTS v_anchor AS
SELECT a.rule_id, r.title, a.art_key, a.short_label, a.caption,
       r.url || '#' || a.anchor AS url_article,
       a.anchor                 AS anchor_article,
       a.para_count
  FROM articles a JOIN rules r USING (rule_id);
