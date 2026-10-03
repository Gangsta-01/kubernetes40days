import os
from flask import Flask, render_template, send_from_directory, abort

app = Flask("My_Portfolio")

# Edit this block to personalise the page.
PROFILE = {
    "name": "Vaibhav Katake",
    "role": "Software developer who likes making things people can touch.",
    "about": "I build web apps and tools, mostly in Python. Replace this paragraph "
             "with two or three sentences about what you do and what you care about.",
    "projects": [
        {"title": "Project one", "text": "One line on what it does and why it matters.", "year": "2026"},
        {"title": "Project two", "text": "One line on what it does and why it matters.", "year": "2025"},
        {"title": "Project three", "text": "One line on what it does and why it matters.", "year": "2024"},
    ],
    "email": "you@example.com",
    "links": [
        {"label": "GitHub", "url": "https://github.com/"},
        {"label": "LinkedIn", "url": "https://www.linkedin.com/"},
    ],
}

STATIC_DIR = os.path.join(app.root_path, "static")


@app.route("/")
def index():
    has_cv = os.path.exists(os.path.join(STATIC_DIR, "cv.pdf"))
    return render_template("index.html", p=PROFILE, has_cv=has_cv)


@app.route("/cv")
def cv():
    # Drop your CV at static/cv.pdf (or mount it into the container).
    if not os.path.exists(os.path.join(STATIC_DIR, "cv.pdf")):
        abort(404)
    return send_from_directory(STATIC_DIR, "cv.pdf")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)
