"""Tokenising and normalising product text for query building and scoring.

Product names in a vendor sheet look like "Amul Butter 500g", "Maggi 70g
Instant Noodles" or "Tata Salt - Iodised". Search engines need the brand next
to the product word, and scoring needs the same information as comparable
token sets, so both share the helpers here.
"""

import re
import unicodedata
from typing import List, Set

# Tokens that carry no discriminative power when matching a photo to a
# product. Kept deliberately small: "pack", "g" and "kg" are meaningful in
# Indian retail, so they are not stop words.
#
# Marketing qualifiers are deliberately absent too. They read as filler in
# English ("good quality", "best price") but in Indian FMCG they are often
# the product's actual name, and dropping them searched for the wrong thing:
# "Britannia Good Day" became the query "britannia day", "Tata Best Quality
# Masala" became "tata masala" and "Surf Excel Best Price" became "surf
# excel". "India" is here for the same reason -- "India Gate" is a brand.
# The fillers that remain are ones no retailer puts in a product name.
_STOP_WORDS: Set[str] = {
    "a", "an", "the", "and", "or", "of", "for", "with", "in", "on", "to",
    "by", "from", "at", "as", "is", "are", "be", "new", "product", "products",
    "item", "items", "online", "buy", "price", "sale", "offer", "shop",
    "store", "free", "shipping", "genuine", "brand",
    "size", "small", "large", "medium",
    "pack", "packed", "packing", "piece", "pieces", "pcs", "each", "per",
}

_TRADEMARK = re.compile(r"[®™©]", re.UNICODE)
# Letters, digits and combining marks of *any* script are kept, not just ASCII.
# An earlier version allowed only [a-z0-9], which silently erased Devanagari,
# Tamil, Telugu and every other Indian script: "मैग्गी इंस्टेंट नूडल्स मसाला"
# cleaned to "", leaving no name tokens and no core phrase. With no brand in
# the sheet that produced an empty query list, so no provider was ever called
# and the row could not match anything at all. Transliteration is left to the
# search engine, which handles these scripts natively.
#
# Mn/Mc/Me are the non-spacing, spacing and enclosing mark categories. They are
# not alphanumeric, so a plain [^\w] split them off the letters they belong to
# and broke one syllable into several tokens.
_MARKS = {"Mn", "Mc", "Me"}

# Splits "500g" / "1litre" into "500" + "g" style units without destroying the
# number itself.
_UNIT_SUFFIX = re.compile(r"^(\d+(?:\.\d+)?)(kg|g|mg|l|ml|ltr|litre|liter|gm)$")

# Words whose singular is not a word anybody writes. A sheet row and a file name
# both say "scissors", so the exact comparison already matches them; stripping
# the "s" would only let a sheet row for scissors match a photograph of a
# single scissor blade.
_ALWAYS_PLURAL = {
    "scissors", "shears", "tongs", "chopsticks", "binoculars", "jeans",
    "trousers", "shorts", "pliers", "clippers", "goggles", "headphones",
    "earphones", "forceps", "flats", "chinos", "boxers", "briefs", "pyjamas",
}


def strip_accents(value: str) -> str:
    """Fold accented characters to ASCII so "Crème" matches "creme".

    Only marks that decorate a *Latin* letter are dropped. Indic scripts use
    combining marks structurally -- the Devanagari virama joins two letters
    into one conjunct, and the Tamil pulli does the same -- so folding them
    the way Latin diacritics fold split single letters apart and left
    unsearchable text: "ம" + virama + "க" became "ம க".
    """
    decomposed = unicodedata.normalize("NFKD", value)
    out: List[str] = []
    for ch in decomposed:
        if unicodedata.combining(ch) and out and _is_latin(out[-1]):
            continue
        out.append(ch)
    return "".join(out)


def _is_latin(ch: str) -> bool:
    try:
        return unicodedata.name(ch).startswith("LATIN")
    except ValueError:
        return False


def clean(value: str) -> str:
    """Lowercase, de-accent and collapse punctuation to single spaces.

    Letters, digits and combining marks of any script are kept. Marks are not
    alphanumeric, so a plain ``\\w`` split them off the letters they belong to
    and turned one Tamil syllable into three tokens.
    """
    if not value:
        return ""
    value = _TRADEMARK.sub(" ", value)
    value = strip_accents(value.lower())
    value = value.replace("&", " and ")
    out: List[str] = []
    for ch in value:
        out.append(ch if ch.isalnum() or unicodedata.category(ch) in _MARKS else " ")
    return re.sub(r"\s+", " ", "".join(out)).strip()


def tokens(value: str) -> List[str]:
    """Meaningful lowercased tokens, stop words removed, order preserved."""
    out: List[str] = []
    for raw in clean(value).split(" "):
        if not raw or raw in _STOP_WORDS:
            continue
        match = _UNIT_SUFFIX.match(raw)
        if match:
            number, unit = match.group(1), match.group(2)
            out.append(number)
            if unit not in {"g", "gm"}:
                out.append(unit)
            continue
        if len(raw) == 1 and not raw.isdigit():
            continue
        out.append(raw)
    return out


def token_set(value: str) -> Set[str]:
    return set(tokens(value))


def words(value: str) -> Set[str]:
    """Every normalised word, stop words included.

    ``tokens`` drops filler because it is used to decide whether two product
    names are the same. That is wrong for detecting *contradicting* words:
    "shop", "store" and "product" are stop words by design, and they are also
    exactly the words that give away a storefront photo. Disqualification needs
    to see them, so it uses this set instead.
    """
    return {w for w in clean(value).split() if w}


def name_phrase(value: str) -> str:
    """A quoted, search-ready phrase: the cleaned text minus filler words."""
    return " ".join(tokens(value)[:8])


def strip_variant(name: str, variant: str) -> str:
    """Remove a size/variant suffix from a name so the core product is left.

    "Maggi 70g" with variant "70g" becomes "maggi", which searches far better
    than a phrase that repeats the weight. Both the raw word ("70g") and its
    token ("500") are tried, longest first, because the sheet and the name can
    disagree on formatting.
    """
    base = clean(name)
    if not variant:
        return base
    words = {w for w in clean(variant).split() if w}
    words |= {t for t in tokens(variant) if t}
    for word in sorted(words, key=len, reverse=True):
        base = re.sub(rf"(^|\s){re.escape(word)}($|\s)", " ", base)
    return re.sub(r"\s+", " ", base).strip()


def _singular(word: str) -> str:
    """A crude singular form, used only to decide whether two words are equal.

    English plural rules applied to retail vocabulary go wrong in ways that
    matter here, so the rules are deliberately narrow: "bus" must not become
    "bu", "glass" must not become "glas", "chest" must not become "ch" (it ends
    in "ches" but takes no "es"). Anything that does not survive those checks
    is returned unchanged, and a word has to keep at least three letters to
    count as having a plural at all.

    Only ASCII words are touched. Indic plural morphology does not follow these
    rules, and guessing at it would corrupt Devanagari or Tamil product names
    rather than help them.
    """
    if not word.isascii() or not word.isalpha() or len(word) < 3:
        return word
    if word in _ALWAYS_PLURAL or word.endswith(("ss", "us", "is")):
        return word
    if word.endswith("ies") and len(word) > 4:
        return word[:-3] + "y"
    for suffix in ("ches", "shes", "sses", "xes", "zes"):
        if word.endswith(suffix) and len(word) - 2 >= 3:
            return word[:-2]
    if word.endswith("s"):
        return word[:-1]
    return word


def _same_word(a: str, b: str) -> bool:
    """Word equality that tolerates a plural on either side."""
    return a == b or _singular(a) == _singular(b)


def coverage(needle: Set[str], haystack: Set[str]) -> float:
    """Fraction of [needle] tokens present in [haystack] (0.0 - 1.0).

    A token counts as present when the two sides differ only in number, so a
    photograph titled "20 mm TMT bars" covers a sheet row that says "TMT Bar".
    """
    if not needle:
        return 0.0
    singular = {_singular(w) for w in haystack}
    hits = sum(1 for w in needle if w in haystack or _singular(w) in singular)
    return hits / len(needle)


def contains_phrase(haystack_text: str, phrase: str) -> bool:
    """True when a multi-word phrase appears in the candidate text.

    Compared word by word rather than as one substring, so a file name that
    pluralises the product still answers to the question the sheet asked. A
    person writing a file name pluralises at least as often as a vendor filling
    a spreadsheet does not, and "20 mm TMT bars" is a photograph of the thing a
    sheet row called "TMT Bar".
    """
    words = clean(haystack_text).split()
    target = clean(phrase).split()
    if not words or not target:
        return False
    span = len(target)
    for start in range(len(words) - span + 1):
        if all(
            _same_word(hay, want)
            for hay, want in zip(words[start : start + span], target)
        ):
            return True
    return False
