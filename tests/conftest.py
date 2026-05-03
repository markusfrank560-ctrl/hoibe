from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import pytest

FIXTURES_DIR = Path(__file__).parent / "fixtures"
RESULTS_DIR = FIXTURES_DIR / "results"
VIDEOS_DIR = FIXTURES_DIR / "videos"


@dataclass
class GoldenFixture:
    """A golden test case loaded from a .result.json file."""

    name: str
    video_path: Path
    ground_truth: bool
    category: str
    mock_response: dict
    description: str


def _load_golden_fixtures() -> list[GoldenFixture]:
    """Auto-discover all .result.json fixtures and pair with videos."""
    fixtures: list[GoldenFixture] = []
    for result_file in sorted(RESULTS_DIR.glob("*.result.json")):
        data = json.loads(result_file.read_text())
        gt = data["ground_truth"]
        stem = result_file.name.replace(".result.json", "")
        video_path = VIDEOS_DIR / f"{stem}.mp4"
        fixtures.append(
            GoldenFixture(
                name=stem,
                video_path=video_path,
                ground_truth=gt["first_sip_detected"],
                category=gt["category"],
                mock_response=data["mock_response"],
                description=gt["description"],
            )
        )
    return fixtures


GOLDEN_FIXTURES = _load_golden_fixtures()


def _matches_case(name: str, selectors: Iterable[str]) -> bool:
    return any(selector in name for selector in selectors)


def _fixture_case_name(item: pytest.Item) -> str:
    callspec = getattr(item, "callspec", None)
    fixture_case = getattr(callspec, "params", {}).get("golden_fixture")
    return getattr(fixture_case, "name", "")


def _filter_case_items(
    config: pytest.Config,
    items: list[pytest.Item],
    *,
    marker_name: str,
    selectors: list[str],
) -> None:
    if not selectors:
        return

    selected_items: list[pytest.Item] = []
    deselected_items: list[pytest.Item] = []
    matched_cases: set[str] = set()

    for item in items:
        if marker_name not in item.keywords:
            selected_items.append(item)
            continue

        fixture_name = _fixture_case_name(item)
        if fixture_name and _matches_case(fixture_name, selectors):
            selected_items.append(item)
            matched_cases.add(fixture_name)
        else:
            deselected_items.append(item)

    if deselected_items:
        config.hook.pytest_deselected(items=deselected_items)
        items[:] = selected_items

    if not matched_cases:
        available_cases = ", ".join(fixture.name for fixture in GOLDEN_FIXTURES)
        selector_text = ", ".join(selectors)
        raise pytest.UsageError(
            f"No {marker_name} fixtures matched: {selector_text}. "
            f"Available cases: {available_cases}"
        )


@pytest.fixture(
    params=GOLDEN_FIXTURES,
    ids=[f.name for f in GOLDEN_FIXTURES],
)
def golden_fixture(request: pytest.FixtureRequest) -> GoldenFixture:
    """Parametrized fixture providing each golden test case."""
    return request.param


def pytest_addoption(parser: pytest.Parser) -> None:
    parser.addoption(
        "--run-integration",
        action="store_true",
        default=False,
        help="Run tests marked as integration",
    )
    parser.addoption(
        "--integration-case",
        action="append",
        default=[],
        metavar="NAME",
        help=(
            "Run only integration cases whose fixture name contains NAME. "
            "Can be passed multiple times and implies --run-integration."
        ),
    )
    parser.addoption(
        "--run-e2e",
        action="store_true",
        default=False,
        help="Run tests marked as e2e against a live Ollama instance",
    )
    parser.addoption(
        "--e2e-case",
        action="append",
        default=[],
        metavar="NAME",
        help=(
            "Run only e2e cases whose fixture name contains NAME. "
            "Can be passed multiple times and implies --run-e2e."
        ),
    )
    parser.addoption(
        "--e2e-full-config",
        action="store_true",
        default=False,
        help="Use the full per-fixture config for e2e tests instead of the fast smoke profile",
    )
    parser.addoption(
        "--e2e-isolate",
        action="store_true",
        default=False,
        help="Unload model between e2e cases for consistent timing (auto-enabled with --e2e-full-config)",
    )
    parser.addoption(
        "--e2e-cooldown",
        type=float,
        default=None,
        metavar="SECONDS",
        help="Override isolation cooldown between cases (default: HOIBE_COOLDOWN env or 5s)",
    )


def pytest_collection_modifyitems(config: pytest.Config, items: list[pytest.Item]) -> None:
    integration_selectors: list[str] = config.getoption("--integration-case")
    e2e_selectors: list[str] = config.getoption("--e2e-case")
    run_integration = config.getoption("--run-integration") or bool(integration_selectors)
    run_e2e = config.getoption("--run-e2e") or bool(e2e_selectors)

    _filter_case_items(
        config,
        items,
        marker_name="integration",
        selectors=integration_selectors,
    )
    _filter_case_items(
        config,
        items,
        marker_name="e2e",
        selectors=e2e_selectors,
    )

    if not run_integration:
        skip_integration = pytest.mark.skip(
            reason="integration tests are skipped by default; use --run-integration"
        )
        for item in items:
            if "integration" in item.keywords:
                item.add_marker(skip_integration)

    if run_e2e:
        return

    skip_e2e = pytest.mark.skip(
        reason="e2e tests are skipped by default; use --run-e2e"
    )
    for item in items:
        if "e2e" in item.keywords:
            item.add_marker(skip_e2e)