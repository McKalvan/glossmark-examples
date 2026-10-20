from flask import Blueprint

from app.platform.auth import public

bp = Blueprint("health", __name__)


# @gloss implements .RequestLogging
@bp.get("/healthz")
@public
def healthz():
    return {"status": "ok"}
