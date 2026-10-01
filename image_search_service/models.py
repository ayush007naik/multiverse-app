"""Request/response models for the image lookup service."""

from typing import List, Literal, Optional

from pydantic import BaseModel, Field

# Which set of search queries produced a candidate. The brand guard reads this:
# a query that named the brand and a query that deliberately left the brand out
# cannot be judged by the same rule, and the candidate is the only place that
# knowledge exists once a provider has returned a result.
#
#   branded -- the sheet's own words, brand included.
#   relaxed -- brand plus the head noun, for long padded names.
#   generic -- the product with the brand removed.
QueryTier = Literal["branded", "relaxed", "generic"]


class ProductQuery(BaseModel):
    """The product details used to find an exact photo of the item."""

    name: str = Field(..., description="Product name, e.g. 'Amul Butter'")
    brand: str = Field("", description="Brand name, e.g. 'Amul'")
    variant: str = Field("", description="Size / flavour, e.g. '500g'")
    category: str = Field("", description="Category, e.g. 'Grocery'")
    subcategory: str = Field("")
    description: str = Field("", description="Free text used to enrich matching")
    barcode: str = Field("", description="EAN/UPC, used to look for exact listings")
    language: str = Field("en", description="Preferred hint language for providers")

    def trimmed(self) -> "ProductQuery":
        return ProductQuery(
            name=self.name.strip(),
            brand=self.brand.strip(),
            variant=self.variant.strip(),
            category=self.category.strip(),
            subcategory=self.subcategory.strip(),
            description=self.description.strip(),
            barcode=self.barcode.strip(),
            language=(self.language.strip() or "en"),
        )


class ImageCandidate(BaseModel):
    """One ranked search result."""

    full_url: str
    thumbnail_url: str
    hosted_url: Optional[str] = None
    title: str = ""
    # Extra searchable text (image description, file name, tags) that is used
    # for relevance scoring but never shown to the vendor.
    tags: str = ""
    source: str
    source_page: Optional[str] = None
    license: Optional[str] = None
    attribution: Optional[str] = None
    requires_attribution: bool = False
    width: Optional[int] = None
    height: Optional[int] = None
    score: float = 0.0
    brand_match: bool = True
    matched_by: Optional[str] = None
    # Stamped by ``providers.search_all`` from the query set it was given, and
    # never inferred from the candidate's own text: a file name cannot say
    # whether the brand was asked for. Defaults to "branded" so a candidate
    # built directly by a provider keeps scoring exactly as it did before
    # query tiers existed.
    tier: QueryTier = "branded"


class SearchResponse(BaseModel):
    query: str
    found: bool
    candidates: List[ImageCandidate] = []
    best: Optional[ImageCandidate] = None
    provider_status: dict = {}
    duration_ms: int = 0


class ResolveRequest(BaseModel):
    product: ProductQuery
    # Optional folder inside the storage bucket. The catalog path is used when
    # the caller already knows the global product id.
    folder: Optional[str] = None
    # How many top-ranked candidates to download and compare before choosing.
    verify_candidates: int = Field(3, ge=1, le=6)
    # Return the ranked grid as well as the winner.
    include_candidates: bool = False
