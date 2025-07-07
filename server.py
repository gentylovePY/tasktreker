from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List
from parser import OzonScraper
import config

app = FastAPI(
    title="Ozon Product Scraper API",
    description="API для поиска и скрапинга товаров на Ozon.ru",
    version="1.0.0",
)

class SearchRequest(BaseModel):

    query: str

class ProductInfoResponse(BaseModel):

    product_id: str
    short_name: str
    full_name: str
    description: str
    url: str
    price: str
    price_with_card: str
    image_url: str

class SearchResponse(BaseModel):

    results: List[ProductInfoResponse]

@app.post("/search", response_model=SearchResponse)
async def search(request: SearchRequest):

    url = f"https://www.ozon.ru/search/?text={request.query}&from_global=true"

    try:
        async with OzonScraper(url) as scraper:
            search_cards = await scraper.get_searchpage_cards()

        results = [
            ProductInfoResponse(
                product_id=card.product_id,
                short_name=card.short_name,
                full_name=card.full_name,
                description=card.description,
                url=f"https://ozon.ru/product/{card.product_id}",
                price=card.price,
                price_with_card=card.price_with_card,
                image_url=card.image_url
            )
            for card in search_cards
        ]

        return SearchResponse(results=results)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An error occurred: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host=config.HOST, port=config.PORT)