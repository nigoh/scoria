import type { AcademicDatabase } from "@/types";

export const PRESET_DATABASES: AcademicDatabase[] = [
  // ── 国際：総合 ──
  { id: "google-scholar", name: "Google Scholar", category: "multidisciplinary_intl", field: "総合", access: "free", url: "https://scholar.google.com/" },
  { id: "scopus", name: "Scopus", category: "multidisciplinary_intl", field: "総合", access: "paid", url: "https://www.scopus.com/" },
  { id: "web-of-science", name: "Web of Science", category: "multidisciplinary_intl", field: "総合", access: "paid", url: "https://www.webofscience.com/" },
  { id: "semantic-scholar", name: "Semantic Scholar", category: "multidisciplinary_intl", field: "総合", access: "free", url: "https://www.semanticscholar.org/" },
  { id: "openalex", name: "OpenAlex", category: "multidisciplinary_intl", field: "総合", access: "oa", url: "https://openalex.org/" },
  { id: "scilit", name: "Scilit", category: "multidisciplinary_intl", field: "総合", access: "free", url: "https://www.scilit.com/" },
  { id: "base", name: "BASE (Bielefeld)", category: "multidisciplinary_intl", field: "総合", access: "free", url: "https://www.base-search.net/" },
  { id: "dimensions", name: "Dimensions", category: "multidisciplinary_intl", field: "総合", access: "free", url: "https://www.dimensions.ai/" },
  { id: "the-lens", name: "The Lens", category: "multidisciplinary_intl", field: "総合（特許含む）", access: "free", url: "https://www.lens.org/" },

  // ── 国際：分野別 ──
  { id: "pubmed", name: "PubMed / MEDLINE", category: "field_specific_intl", field: "医学・生命科学", access: "free", url: "https://pubmed.ncbi.nlm.nih.gov/" },
  { id: "pmc", name: "PubMed Central (PMC)", category: "field_specific_intl", field: "医学・生命科学", access: "oa", url: "https://www.ncbi.nlm.nih.gov/pmc/" },
  { id: "ieee-xplore", name: "IEEE Xplore", category: "field_specific_intl", field: "工学・情報科学", access: "paid", url: "https://ieeexplore.ieee.org/" },
  { id: "acm-dl", name: "ACM Digital Library", category: "field_specific_intl", field: "情報科学", access: "paid", url: "https://dl.acm.org/" },
  { id: "arxiv", name: "arXiv", category: "field_specific_intl", field: "物理・数学・CS等", access: "oa", url: "https://arxiv.org/" },
  { id: "biorxiv", name: "bioRxiv", category: "field_specific_intl", field: "生物学", access: "oa", url: "https://www.biorxiv.org/" },
  { id: "medrxiv", name: "medRxiv", category: "field_specific_intl", field: "医学", access: "oa", url: "https://www.medrxiv.org/" },
  { id: "ssrn", name: "SSRN", category: "field_specific_intl", field: "社会科学・人文学", access: "free", url: "https://www.ssrn.com/" },
  { id: "jstor", name: "JSTOR", category: "field_specific_intl", field: "人文・社会科学", access: "paid", url: "https://www.jstor.org/" },
  { id: "project-muse", name: "Project MUSE", category: "field_specific_intl", field: "人文・社会科学", access: "paid", url: "https://muse.jhu.edu/" },
  { id: "philpapers", name: "PhilPapers", category: "field_specific_intl", field: "哲学", access: "free", url: "https://philpapers.org/" },
  { id: "eric", name: "ERIC", category: "field_specific_intl", field: "教育学", access: "free", url: "https://eric.ed.gov/" },
  { id: "psycinfo", name: "PsycINFO / APA PsycNet", category: "field_specific_intl", field: "心理学", access: "paid", url: "https://psycnet.apa.org/" },
  { id: "econlit", name: "EconLit", category: "field_specific_intl", field: "経済学", access: "paid", url: "https://www.aeaweb.org/econlit/" },
  { id: "sciencedirect", name: "ScienceDirect", category: "field_specific_intl", field: "総合（Elsevier）", access: "paid", url: "https://www.sciencedirect.com/" },
  { id: "springerlink", name: "SpringerLink", category: "field_specific_intl", field: "総合（Springer）", access: "paid", url: "https://link.springer.com/" },
  { id: "wiley", name: "Wiley Online Library", category: "field_specific_intl", field: "総合（Wiley）", access: "paid", url: "https://onlinelibrary.wiley.com/" },
  { id: "doaj", name: "DOAJ", category: "field_specific_intl", field: "総合（OA誌）", access: "oa", url: "https://doaj.org/" },
  { id: "cochrane", name: "Cochrane Library", category: "field_specific_intl", field: "医学（SR/メタ分析）", access: "paid", url: "https://www.cochranelibrary.com/" },
  { id: "dblp", name: "DBLP", category: "field_specific_intl", field: "情報科学", access: "free", url: "https://dblp.org/" },
  { id: "nasa-ads", name: "NASA ADS", category: "field_specific_intl", field: "天文学・物理", access: "free", url: "https://ui.adsabs.harvard.edu/" },
  { id: "mathscinet", name: "MathSciNet", category: "field_specific_intl", field: "数学", access: "paid", url: "https://mathscinet.ams.org/" },
  { id: "chemspider", name: "ChemSpider / Reaxys", category: "field_specific_intl", field: "化学", access: "free", url: "https://www.chemspider.com/" },
  { id: "georef", name: "GeoRef", category: "field_specific_intl", field: "地球科学", access: "paid", url: "https://www.americangeosciences.org/georef" },
  { id: "agricola", name: "Agricola", category: "field_specific_intl", field: "農学", access: "free", url: "https://agricola.nal.usda.gov/" },
  { id: "sage-journals", name: "SAGE Journals", category: "field_specific_intl", field: "社会科学", access: "paid", url: "https://journals.sagepub.com/" },
  { id: "taylor-francis", name: "Taylor & Francis Online", category: "field_specific_intl", field: "総合", access: "paid", url: "https://www.tandfonline.com/" },

  // ── 国際：ツール系 ──
  { id: "connected-papers", name: "Connected Papers", category: "tool", field: "論文関係可視化", access: "free", url: "https://www.connectedpapers.com/" },
  { id: "research-rabbit", name: "Research Rabbit", category: "tool", field: "論文探索・推薦", access: "free", url: "https://www.researchrabbit.ai/" },
  { id: "elicit", name: "Elicit", category: "tool", field: "AI文献レビュー", access: "free", url: "https://elicit.com/" },
  { id: "consensus", name: "Consensus", category: "tool", field: "AI学術検索", access: "free", url: "https://consensus.app/" },
  { id: "perplexity", name: "Perplexity", category: "tool", field: "AI検索（学術対応）", access: "free", url: "https://www.perplexity.ai/" },

  // ── 日本国内 ──
  { id: "cinii-research", name: "CiNii Research", category: "domestic_jp", field: "総合（国内最大）", access: "free", url: "https://cir.nii.ac.jp/" },
  { id: "cinii-books", name: "CiNii Books", category: "domestic_jp", field: "図書所蔵", access: "free", url: "https://ci.nii.ac.jp/books/" },
  { id: "cinii-dissertations", name: "CiNii Dissertations", category: "domestic_jp", field: "博士論文", access: "free", url: "https://ci.nii.ac.jp/d/" },
  { id: "j-stage", name: "J-STAGE", category: "domestic_jp", field: "総合（学会誌）", access: "free", url: "https://www.jstage.jst.go.jp/" },
  { id: "jxiv", name: "Jxiv", category: "domestic_jp", field: "プレプリント（JST）", access: "oa", url: "https://jxiv.jst.go.jp/" },
  { id: "ndl-online", name: "NDL ONLINE", category: "domestic_jp", field: "国立国会図書館", access: "free", url: "https://ndlonline.ndl.go.jp/" },
  { id: "ndl-magazine", name: "NDL雑誌記事索引", category: "domestic_jp", field: "雑誌記事", access: "free", url: "https://ndlonline.ndl.go.jp/" },
  { id: "irdb", name: "IRDB（学術機関リポジトリ）", category: "domestic_jp", field: "機関リポジトリ横断", access: "free", url: "https://irdb.nii.ac.jp/" },
  { id: "ichushi", name: "医中誌Web", category: "domestic_jp", field: "医学（国内）", access: "paid", url: "https://www.jamas.or.jp/" },
  { id: "kaken", name: "KAKEN（科研費）", category: "domestic_jp", field: "研究課題・成果", access: "free", url: "https://kaken.nii.ac.jp/" },
  { id: "j-global", name: "J-GLOBAL", category: "domestic_jp", field: "科学技術（JST）", access: "free", url: "https://jglobal.jst.go.jp/" },
  { id: "webcat-plus", name: "Webcat Plus", category: "domestic_jp", field: "図書連想検索", access: "free", url: "http://webcatplus.nii.ac.jp/" },

  // ── 特許 ──
  { id: "google-patents", name: "Google Patents", category: "patent", field: "特許（国際）", access: "free", url: "https://patents.google.com/" },
  { id: "j-platpat", name: "J-PlatPat", category: "patent", field: "特許（日本）", access: "free", url: "https://www.j-platpat.inpit.go.jp/" },
  { id: "espacenet", name: "Espacenet", category: "patent", field: "特許（欧州）", access: "free", url: "https://worldwide.espacenet.com/" },
];

export const ALL_DATABASE_IDS = PRESET_DATABASES.map((db) => db.id);

export const DATABASE_CATEGORY_LABELS: Record<string, string> = {
  multidisciplinary_intl: "国際：総合",
  field_specific_intl: "国際：分野別",
  tool: "国際：ツール系",
  domestic_jp: "日本国内",
  patent: "特許",
};
