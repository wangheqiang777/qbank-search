import openpyxl, json, re, random

PATH = r"C:\Users\Administrator\Desktop\新2025强基练兵题库单选、多选、判断.xlsx"
OUT = r"C:\Users\Administrator\Projects\qbank-search\bank.json"

def norm(s):
    if s is None:
        return ""
    s = str(s).lower()
    s = re.sub(r'[^\w\u4e00-\u9fff]', '', s)   # 去标点/空格/换行
    return s

def bigrams(s):
    return set(s[i:i+2] for i in range(len(s)-1)) if len(s) > 1 else set([s])

def jaccard(a, b):
    if not a or not b:
        return 0.0
    u = len(a | b)
    return len(a & b) / u if u else 0.0

# ---------- 1. 解析 Excel -> 结构化记录 ----------
wb = openpyxl.load_workbook(PATH, read_only=True, data_only=True)
records = []
for sheet in ['单选题', '多选题', '判断题']:
    ws = wb[sheet]
    rows = list(ws.iter_rows(values_only=True))
    for row in rows[1:]:
        q = row[0]
        if q is None or str(q).strip() == '':
            continue
        q = str(q).strip()
        ans = '' if row[1] is None else str(row[1]).strip()
        opts = []
        for v in row[2:7]:
            if v is None:
                continue
            v = str(v).strip()
            if v:
                opts.append(v)
        if sheet == '判断题':
            ans_text = ans
        else:
            letters = re.findall(r'[A-E]', ans)
            parts = []
            for L in letters:
                idx = ord(L) - ord('A')
                if idx < len(opts):
                    parts.append(f"{L}.{opts[idx]}")
            ans_text = ' / '.join(parts)
        nq = norm(q)
        records.append({
            'type': sheet, 'q': q, 'ans': ans,
            'ans_text': ans_text, 'opts': opts,
            '_nq': nq, '_nb': bigrams(nq)
        })

clean = [{k: v for k, v in r.items() if not k.startswith('_')} for r in records]
with open(OUT, 'w', encoding='utf-8') as f:
    json.dump(clean, f, ensure_ascii=False, indent=1)

print(f"解析完成：共 {len(records)} 道题 -> {OUT}")
from collections import Counter
print("题型分布：", dict(Counter(r['type'] for r in records)))

# ---------- 2. 匹配引擎 ----------
def search(query, topk=3):
    nq = norm(query)
    nbq = bigrams(nq)
    scored = []
    for r in records:
        if nq and nq in r['_nq']:
            score = 1.0                      # 精确子串命中
        else:
            score = jaccard(nbq, r['_nb'])    # n-gram 余弦兜底
        scored.append((score, r))
    scored.sort(key=lambda x: -x[0])
    return scored[:topk]

# ---------- 3. 自测：用原题当查询，看 top1 是否命中 ----------
def self_test(records, noisy=False, n=200, seed=42):
    random.seed(seed)
    sample = random.sample(records, min(n, len(records)))
    hit1 = 0
    scores = []
    for r in sample:
        q = r['q']
        if noisy:
            chars = list(q)
            drop = max(1, int(len(chars) * 0.12))
            for _ in range(drop):
                if chars:
                    chars.pop(random.randrange(len(chars)))
            q = ''.join(chars)
        top = search(q, 1)[0]
        scores.append(top[0])
        if top[1]['q'] == r['q']:
            hit1 += 1
    return hit1 / len(sample), sum(scores) / len(scores)

clean_recall, clean_sim = self_test(records, noisy=False)
noisy_recall, noisy_sim = self_test(records, noisy=True)
print(f"\n[自测] 干净查询  recall@1={clean_recall:.3f}  avg_top1_sim={clean_sim:.3f}")
print(f"[自测] 含噪查询(删12%字) recall@1={noisy_recall:.3f}  avg_top1_sim={noisy_sim:.3f}")

# ---------- 4. 演示：抽几道题当"截图OCR结果" ----------
print("\n" + "=" * 70)
print("演示搜索（模拟考试时截图OCR出的题目文字）")
print("=" * 70)
demos = [
    "阿托品用于有机磷中毒患者的救治，对下述哪种症状无效？",
    "《传染病防治法》中规定的甲类传染病为?",
    "DVT诊断的“金标准”是静脉造影。",
]
for d in demos:
    print(f"\n查询：{d}")
    for sc, r in search(d, 3):
        print(f"  [{sc:.3f}] ({r['type']}) {r['q'][:30]}... -> {r['ans_text']}")
