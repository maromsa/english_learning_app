import os
import requests
import cloudinary
from cloudinary import uploader

# רשימת המילים להעלאה
WORDS_TO_UPLOAD = [
    'Apple', 'Banana', 'Car', 'Dog', 'Cat', 'House', 'Tree', 'Sun', 'Moon', 'Star'
]
APP_TAG = 'english_kids_app'

def search_image_on_pixabay(query, api_key):
    url = f"https://pixabay.com/api/?key={api_key}&q={requests.utils.quote(query)}&image_type=photo&orientation=horizontal&per_page=3"
    print(f"  - Searching Pixabay for '{query}'...")
    response = requests.get(url)
    response.raise_for_status()
    data = response.json()
    if data.get('hits'):
        image_url = data['hits'][0]['webformatURL']
        print(f"  - Found image URL: {image_url}")
        return image_url
    print(f"  - No image found for '{query}'.")
    return None

def main():
    cloudinary_cloud_name = os.environ.get('CLOUDINARY_CLOUD_NAME')
    cloudinary_api_key = os.environ.get('CLOUDINARY_API_KEY')
    cloudinary_api_secret = os.environ.get('CLOUDINARY_API_SECRET')
    pixabay_api_key = os.environ.get('PIXABAY_API_KEY')

    if not all([pixabay_api_key, cloudinary_cloud_name, cloudinary_api_key, cloudinary_api_secret]):
        print("❌ Error: Missing required environment variables. Please set CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET, and PIXABAY_API_KEY.")
        return

    cloudinary.config(cloud_name=cloudinary_cloud_name, api_key=cloudinary_api_key, api_secret=cloudinary_api_secret)
    print("--- Python script started. Configured Cloudinary. ---")

    for word in WORDS_TO_UPLOAD:
        try:
            print(f"\nProcessing word: '{word}'")
            image_url = search_image_on_pixabay(word, pixabay_api_key)
            if not image_url: continue

            print(f"  - Uploading to Cloudinary with tags: ['{APP_TAG}', '{word.lower()}']")
            upload_result = uploader.upload(image_url, tags=[APP_TAG, word.lower()], public_id=word.lower(), folder=APP_TAG)

            print(f"  - ✅ Successfully uploaded '{word}'. Public ID: {upload_result.get('public_id')}")
        except Exception as e:
            print(f"  - ❌ An error occurred while processing '{word}': {e}")

    print("\n--- ✅ Python script finished. ---")

if __name__ == "__main__":
    main()