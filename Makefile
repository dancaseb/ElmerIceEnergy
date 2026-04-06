# SPDX-FileCopyrightText: (C) 2026 Marco Celoria <celoria.marco@gmail.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

.PHONY: sync lint format

sync:
	uv sync

lint:
	flake8 recipes
	mypy recipes
	isort --check-only recipes

format:
	black recipes
	isort recipes
