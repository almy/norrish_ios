# HealthScanner Phase 1 API Contract

This contract defines the minimal synchronous API for Phase 0/1. In Phase 0 there is no persistence; in Phase 1 the same API can be backed by a database.

---

## Conventions

- **Base URL**: `/v1`
- **Auth**: Bearer token (Sign in with Apple JWT)
- **Content-Type**: `application/json`
- **Time limits**: 8-10s hard timeout for any external call

**Error format**
```json
{
  "error": {
    "code": "invalid_request",
    "message": "Readable error message",
    "request_id": "req_123"
  }
}
```

---

## Endpoints

### POST /v1/scans/plate

Synchronous plate scan. Uses device detections + heuristics; may call external services inline.

**Request**
```json
{
  "deviceId": "ios-uuid",
  "detections": [
    {
      "label": "salmon",
      "confidence": 0.92,
      "volumeML": 240,
      "massG": 120,
      "calories": 260,
      "protein": 24,
      "carbs": 0,
      "fat": 16
    }
  ],
  "heuristics": {
    "mealType": "lunch",
    "notes": "home cooked"
  }
}
```

**Response**
```json
{
  "scanId": "scan_123",
  "status": "completed",
  "analysis": {
    "nutritionScore": 8.5,
    "description": "Healthy Quinoa Bowl",
    "macronutrients": {
      "protein": 25,
      "carbs": 40,
      "fat": 15,
      "calories": 450
    },
    "ingredients": [
      {
        "name": "Quinoa",
        "amount": "100g"
      }
    ],
    "insights": [
      {
        "type": "positive",
        "title": "Excellent Protein Source",
        "description": "This meal provides complete proteins from quinoa."
      }
    ],
    "micronutrients": {
      "fiberG": 8,
      "vitaminCMg": 85,
      "ironMg": 4,
      "other": "Rich in vitamin K, folate, and magnesium"
    },
    "connections": [
      "High fiber content supports digestive health"
    ]
  }
}
```

---

### POST /v1/scans/barcode

Synchronous barcode lookup.

**Request**
```json
{
  "barcode": "7310865004705",
  "locale": "sv_SE"
}
```

**Response**
```json
{
  "scanId": "scan_456",
  "status": "completed",
  "product": {
    "barcode": "7310865004705",
    "name": "Product Name",
    "brand": "Brand",
    "nutritionData": {
      "calories": 240,
      "fat": 9,
      "saturatedFat": 2,
      "sugar": 12,
      "sodium": 0.8,
      "protein": 8,
      "fiber": 4,
      "carbohydrates": 30,
      "fruitsVegetablesNutsPercent": null
    },
    "imageURL": "https://example.com/image.jpg",
    "categoriesTags": ["en:breakfast-cereals"],
    "ingredients": "Whole grain oats, sugar, salt",
    "scannedDate": "2025-02-01T12:34:56Z"
  }
}
```

---

### GET /v1/users/me/history

Recent scans (most recent first). Items align with existing `Product` and `PlateAnalysisHistory`.

**Phase 0 note**: This endpoint can be omitted or return `[]` since the backend is stateless and the app is source-of-truth.

**Response**
```json
{
  "items": [
    {
      "type": "product",
      "barcode": "7310865004705",
      "name": "Product Name",
      "brand": "Brand",
      "nutritionData": {
        "calories": 240,
        "fat": 9,
        "saturatedFat": 2,
        "sugar": 12,
        "sodium": 0.8,
        "protein": 8,
        "fiber": 4,
        "carbohydrates": 30,
        "fruitsVegetablesNutsPercent": null
      },
      "imageURL": "https://example.com/image.jpg",
      "categoriesTags": ["en:breakfast-cereals"],
      "ingredients": "Whole grain oats, sugar, salt",
      "scannedDate": "2025-02-01T12:34:56Z"
    },
    {
      "type": "plate",
      "id": "e357a3f2-49ae-4af6-9e41-997fb6f36c3a",
      "name": "Lunch",
      "analyzedDate": "2025-02-01T12:40:20Z",
      "nutritionScore": 8.5,
      "description": "This meal is a great source of protein and balanced nutrients.",
      "protein": 25,
      "carbs": 40,
      "fat": 20,
      "calories": 450,
      "ingredients": [
        {
          "name": "Quinoa",
          "amount": "100g"
        }
      ],
      "insights": [
        {
          "type": "positive",
          "title": "Excellent Source of Protein",
          "description": "Helps with muscle repair and growth."
        }
      ],
      "micronutrients": {
        "fiberG": 8,
        "vitaminCMg": 85,
        "ironMg": 4,
        "other": "Rich in vitamin K, folate, and magnesium"
      },
      "connections": [
        "High fiber content supports digestive health"
      ]
    }
  ]
}
```

---

### PUT /v1/users/me/preferences

**Phase 0 note**: This endpoint can be omitted or accepted as a no-op if preferences remain on-device only.

**Request**
```json
{
  "selectedAllergies": ["peanuts", "dairy"],
  "selectedDietaryRestrictions": ["vegetarian", "low_carb"],
  "customAllergies": ["pineapple"],
  "customRestrictions": ["low_histamine"]
}
```

**Response**
```json
{
  "updated": true
}
```

---

### GET /v1/health

**Response**
```json
{
  "status": "ok",
  "db": "ok"
}
```

---

## Pydantic Models (FastAPI)

```python
from pydantic import BaseModel, Field
from typing import List, Optional, Dict


class ARPlateScanNutrition(BaseModel):
    label: str
    confidence: float = Field(ge=0.0, le=1.0)
    volume_ml: float = Field(alias="volumeML", ge=0.0)
    mass_g: float = Field(alias="massG", ge=0.0)
    calories: int = Field(ge=0)
    protein: int = Field(ge=0)
    carbs: int = Field(ge=0)
    fat: int = Field(ge=0)


class PlateScanRequest(BaseModel):
    device_id: str = Field(alias="deviceId")
    detections: List[ARPlateScanNutrition]
    heuristics: Optional[Dict[str, str]] = None


class Macronutrients(BaseModel):
    protein: int
    carbs: int
    fat: int
    calories: int


class PlateIngredient(BaseModel):
    name: str
    amount: str


class PlateInsight(BaseModel):
    type: str
    title: str
    description: str


class Micronutrients(BaseModel):
    fiber_g: Optional[int] = Field(default=None, alias="fiberG")
    vitamin_c_mg: Optional[int] = Field(default=None, alias="vitaminCMg")
    iron_mg: Optional[int] = Field(default=None, alias="ironMg")
    other: Optional[str] = None


class PlateAnalysis(BaseModel):
    nutrition_score: float = Field(alias="nutritionScore")
    description: str
    macronutrients: Macronutrients
    ingredients: List[PlateIngredient]
    insights: List[PlateInsight]
    micronutrients: Optional[Micronutrients] = None
    connections: Optional[List[str]] = None


class PlateScanResponse(BaseModel):
    scan_id: str = Field(alias="scanId")
    status: str
    analysis: PlateAnalysis


class BarcodeRequest(BaseModel):
    barcode: str
    locale: Optional[str] = "sv_SE"


class NutritionData(BaseModel):
    calories: float
    fat: float
    saturated_fat: float = Field(alias="saturatedFat")
    sugar: float
    sodium: float
    protein: float
    fiber: float
    carbohydrates: float
    fruits_vegetables_nuts_percent: Optional[float] = Field(default=None, alias="fruitsVegetablesNutsPercent")


class ProductPayload(BaseModel):
    barcode: str
    name: str
    brand: str
    nutrition_data: NutritionData = Field(alias="nutritionData")
    image_url: Optional[str] = Field(default=None, alias="imageURL")
    categories_tags: Optional[List[str]] = Field(default=None, alias="categoriesTags")
    ingredients: Optional[str] = None
    scanned_date: Optional[str] = Field(default=None, alias="scannedDate")


class BarcodeResponse(BaseModel):
    scan_id: str = Field(alias="scanId")
    status: str
    product: ProductPayload
```

---

## Swift Models (Client)

```swift
// Reuse existing app models:
// - ARPlateScanNutrition (Scanning/AR/ARPlateScanNutrition.swift)
// - PlateAnalysis + Macronutrients + Ingredient + Insight + Micronutrients (Models/PlateAnalysis.swift)
// - NutritionData + Product (Models/Product.swift)
// - PlateAnalysisHistory (Models/PlateAnalysisHistory.swift)

struct PlateScanRequest: Codable {
    let deviceId: String
    let detections: [ARPlateScanNutritionPayload]
    let heuristics: [String: String]?
}

struct ARPlateScanNutritionPayload: Codable {
    let label: String
    let confidence: Double
    let volumeML: Double
    let massG: Double
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
}

struct PlateScanResponse: Codable {
    let scanId: String
    let status: String
    let analysis: PlateAnalysis
}

struct BarcodeRequest: Codable {
    let barcode: String
    let locale: String?
}

struct ProductPayload: Codable {
    let barcode: String
    let name: String
    let brand: String
    let nutritionData: NutritionData
    let imageURL: String?
    let categoriesTags: [String]?
    let ingredients: String?
    let scannedDate: Date?
}

struct BarcodeResponse: Codable {
    let scanId: String
    let status: String
    let product: ProductPayload
}
```

---

## Phase 1 Database Schema (Minimal)

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_provider_id TEXT UNIQUE NOT NULL,
  locale TEXT DEFAULT 'sv_SE',
  created_at TIMESTAMPTZ DEFAULT now(),
  last_seen_at TIMESTAMPTZ
);

CREATE TABLE scans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  type TEXT CHECK (type IN ('plate', 'barcode')),
  status TEXT CHECK (status IN ('completed', 'failed')),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE scan_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scan_id UUID REFERENCES scans(id) ON DELETE CASCADE,
  payload_json JSONB NOT NULL
);

CREATE TABLE user_preferences (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  selected_allergies TEXT[],
  selected_dietary_restrictions TEXT[],
  custom_allergies TEXT[],
  custom_restrictions TEXT[],
  updated_at TIMESTAMPTZ DEFAULT now()
);
```
