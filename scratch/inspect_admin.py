import re

path = r'C:\Users\DELL\.gemini\antigravity-ide\brain\ac7e04dd-c222-42cd-9293-b4e2790394d1\.system_generated\steps\71\content.md'
with open(path, 'r', encoding='utf-8', errors='ignore') as f:
    text = f.read()

print(f"Total length: {len(text)}")
urls = re.findall(r'https?://[^\s"\'<>]+', text)
print("URLs found:")
for u in set(urls)[:20]:
    print("  ", u)

# Search for firestore collections
collections = re.findall(r'collection\([a-zA-Z0-9_$,\s]+["\']([a-zA-Z0-9_\-]+)["\']\)', text)
print("\nFirestore collections:")
for c in set(collections):
    print("  ", c)

# Search for doc paths
docs = re.findall(r'doc\([a-zA-Z0-9_$,\s]+["\']([a-zA-Z0-9_\-]+)["\']\)', text)
print("\nDocs:")
for d in set(docs):
    print("  ", d)

# Search for Cloudflare worker or API calls
workers = re.findall(r'https?://[a-zA-Z0-9\.\-_]*workers\.dev[^\s"\'<>]*', text)
print("\nWorkers URLs:")
for w in set(workers):
    print("  ", w)

# Search for Kurdish text or section names in admin
kurdish = re.findall(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]{4,}', text)
print(f"\nKurdish phrases ({len(kurdish)} found, sample 15):")
for k in set(kurdish[:50]):
    print("  ", k)
