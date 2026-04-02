# SPDX-FileCopyrightText: (C) 2026 Marco Celoria <celoria.marco@gmail.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

.PHONY: sync lint format

sync:
	uv sync

lint:
	flake8 src
	mypy src
	isort --check-only src

format:
	black src
	isort src
