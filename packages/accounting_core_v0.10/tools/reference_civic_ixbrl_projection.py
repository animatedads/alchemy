#!/usr/bin/env python3
"""Reference-only Companies House iXBRL -> Civic accounting projection.

This is a qualification helper for the accounting.civic.companieshouse/0.2
contract. Production parsing belongs in Civic, not Accounting Core.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
from datetime import datetime
from pathlib import Path
import xml.etree.ElementTree as ET

IX = "http://www.xbrl.org/2013/inlineXBRL"
XBRLI = "http://www.xbrl.org/2003/instance"
XBRLDI = "http://xbrl.org/2006/xbrldi"
XLINK = "http://www.w3.org/1999/xlink"


def collect_namespaces(data: bytes) -> dict[str, str]:
    ns: dict[str, str] = {}
    for _, item in ET.iterparse(io.BytesIO(data), events=("start-ns",)):
        prefix, uri = item
        ns[prefix or ""] = uri
    return ns


def canonical_qname(text: str | None, ns: dict[str, str]) -> str:
    if not text:
        return ""
    text = text.strip()
    if not text:
        return ""
    if text.startswith("{"):
        return text
    if ":" in text:
        prefix, local = text.split(":", 1)
        uri = ns.get(prefix, "")
        return f"{{{uri}}}{local}" if uri else text
    uri = ns.get("", "")
    return f"{{{uri}}}{text}" if uri else text


def local_name(qname: str) -> str:
    if qname.startswith("{") and "}" in qname:
        return qname.split("}", 1)[1]
    return qname.split(":", 1)[-1]


def all_text(node: ET.Element) -> str:
    return "".join(node.itertext()).strip()


def iso_date_from_ix(text: str, fmt: str) -> str:
    text = text.strip()
    if not text:
        return ""
    if fmt.endswith("datedaymonthyear"):
        return datetime.strptime(text, "%d.%m.%y").date().isoformat()
    if fmt.endswith("datedaymonthyearen"):
        return datetime.strptime(text, "%d %B %Y").date().isoformat()
    return text


def normalized_value(node: ET.Element, lexical: str) -> str:
    fmt = node.attrib.get("format", "")
    value = lexical.strip()
    if fmt.endswith("zerodash") and value == "-":
        return "0"
    if fmt.endswith("numdotdecimal"):
        value = value.replace(",", "")
    if fmt.endswith("booleantrue"):
        return "true"
    if fmt.endswith("booleanfalse"):
        return "false"
    if "datedaymonthyear" in fmt:
        return iso_date_from_ix(value, fmt)
    scale = node.attrib.get("scale")
    if node.tag == f"{{{IX}}}nonFraction" and value and re.fullmatch(r"[-+]?\d+(?:\.\d+)?", value):
        if scale and scale not in ("", "0"):
            # Exact decimal expansion; no binary floating point.
            neg = value.startswith("-")
            unsigned = value.lstrip("+-")
            whole, dot, frac = unsigned.partition(".")
            digits = whole + frac
            exponent = int(scale) - len(frac)
            if exponent >= 0:
                out = digits + ("0" * exponent)
            else:
                split = len(digits) + exponent
                if split <= 0:
                    out = "0." + ("0" * (-split)) + digits
                else:
                    out = digits[:split] + "." + digits[split:]
            return ("-" if neg else "") + out
        return value
    return value


def parse_contexts(root: ET.Element, nsmap: dict[str, str]) -> dict[str, dict]:
    contexts: dict[str, dict] = {}
    for ctx in root.iter(f"{{{XBRLI}}}context"):
        cid = ctx.attrib.get("id", "")
        entity_id = ""
        identifier = ctx.find(f".//{{{XBRLI}}}identifier")
        if identifier is not None and identifier.text:
            entity_id = identifier.text.strip()
        period = ctx.find(f"{{{XBRLI}}}period")
        start = end = instant = ""
        if period is not None:
            e = period.find(f"{{{XBRLI}}}startDate")
            if e is not None and e.text:
                start = e.text.strip()
            e = period.find(f"{{{XBRLI}}}endDate")
            if e is not None and e.text:
                end = e.text.strip()
            e = period.find(f"{{{XBRLI}}}instant")
            if e is not None and e.text:
                instant = e.text.strip()
        dims: dict[str, str] = {}
        for member in ctx.iter(f"{{{XBRLDI}}}explicitMember"):
            dim = canonical_qname(member.attrib.get("dimension"), nsmap)
            dims[dim] = canonical_qname(member.text, nsmap)
        for member in ctx.iter(f"{{{XBRLDI}}}typedMember"):
            dim = canonical_qname(member.attrib.get("dimension"), nsmap)
            child = next(iter(member), None)
            if child is not None:
                dims[dim] = "typed:" + canonical_qname(child.tag, nsmap) + "=" + all_text(child)
        contexts[cid] = {
            "entity_id": entity_id,
            "period_start": start,
            "period_end": end,
            "instant_date": instant,
            "dimensions": dims,
        }
    return contexts


def find_fact_text(facts: list[ET.Element], source_local: str) -> str:
    for fact in facts:
        if local_name(fact.attrib.get("name", "")) == source_local:
            value = normalized_value(fact, all_text(fact))
            if value:
                return value
    return ""


def dimension_members(contexts: dict[str, dict], dimension_local: str) -> list[str]:
    values: list[str] = []
    for ctx in contexts.values():
        for dim, member in ctx["dimensions"].items():
            if local_name(dim) == dimension_local:
                values.append(local_name(member))
    return sorted(set(values))


def build_projection(path: Path) -> dict:
    body = path.read_bytes()
    nsmap = collect_namespaces(body)
    root = ET.fromstring(body)
    contexts = parse_contexts(root, nsmap)
    facts = [e for e in root.iter() if e.tag in (f"{{{IX}}}nonFraction", f"{{{IX}}}nonNumeric")]

    sha512 = hashlib.sha512(body).hexdigest()
    sha256 = hashlib.sha256(body).hexdigest()
    company_number = find_fact_text(facts, "UKCompaniesHouseRegisteredNumber")
    company_name = find_fact_text(facts, "EntityCurrentLegalOrRegisteredName")
    period_start = find_fact_text(facts, "StartDateForPeriodCoveredByReport")
    period_end = find_fact_text(facts, "EndDateForPeriodCoveredByReport")
    authorised_at = find_fact_text(facts, "DateAuthorisationFinancialStatementsForIssue")

    taxonomy_refs = []
    for schema in root.iter("{http://www.xbrl.org/2003/linkbase}schemaRef"):
        href = schema.attrib.get(f"{{{XLINK}}}href", "")
        if href:
            taxonomy_refs.append(href)

    account_status = dimension_members(contexts, "AccountsStatusDimension")
    account_types = dimension_members(contexts, "AccountsTypeDimension")
    standards = dimension_members(contexts, "AccountingStandardsDimension")
    legislation = dimension_members(contexts, "ApplicableLegislationDimension")

    output_facts = []
    seen = {}
    ordinal = 0
    for node in facts:
        ordinal += 1
        source_name = node.attrib.get("name", "")
        concept = canonical_qname(source_name, nsmap)
        context_ref = node.attrib.get("contextRef", "")
        context = contexts.get(context_ref, {})
        lexical = all_text(node)
        normalized = normalized_value(node, lexical)
        unit_ref = node.attrib.get("unitRef", "")
        kind = "DECIMAL" if node.tag == f"{{{IX}}}nonFraction" else "TEXT"
        fmt = node.attrib.get("format", "")
        if "boolean" in fmt:
            kind = "BOOLEAN"
        elif "date" in fmt:
            kind = "DATE"

        duplicate_key = (concept, context_ref, unit_ref, normalized)
        duplicate_of = seen.get(duplicate_key, "")
        pointer = f"ixbrl:fact-document-order[{ordinal}]"
        if not duplicate_of:
            seen[duplicate_key] = pointer

        provenance = {
            "source_concept_qname": source_name,
            "source_context_ref": context_ref,
            "source_unit_ref": unit_ref,
            "source_format": fmt,
            "source_decimals": node.attrib.get("decimals", ""),
            "source_scale": node.attrib.get("scale", ""),
            "source_element": local_name(node.tag),
            "normalized_value": normalized,
            "duplicate_of": duplicate_of,
        }
        fact = {
            "concept_id": concept,
            "lexical_value": lexical,
            "value_type": kind,
            "currency": unit_ref if unit_ref in {"GBP", "USD", "EUR"} else "",
            "unit": unit_ref,
            "period_start": context.get("period_start", ""),
            "period_end": context.get("period_end", ""),
            "instant_date": context.get("instant_date", ""),
            "source_pointer": pointer,
            "mapping_state": "REPORTED_DUPLICATE" if duplicate_of else "REPORTED",
            "dimensions": context.get("dimensions", {}),
            "provenance": provenance,
        }
        output_facts.append(fact)

    income_omission = find_fact_text(facts, "StatementThatDirectorsHaveElectedNotToDeliverProfitLossAccountUnderSection4445ACompaniesAct2006")
    filing_match = re.search(r"_(\d{4}-\d{2}-\d{2})\.xhtml$", path.name)
    filing_date = filing_match.group(1) if filing_match else ""

    reporting_basis = "FRS_102"
    if "SmallEntities" in standards:
        reporting_basis = "FRS_102_SECTION_1A_SMALL_ENTITIES"

    completeness = {
        "balance_sheet_delivered": bool(find_fact_text(facts, "TotalAssetsLessCurrentLiabilities")),
        "income_statement_delivered": not bool(income_omission),
        "notes_delivered": bool(find_fact_text(facts, "StatementComplianceWithApplicableReportingFramework")),
        "income_statement_omission_statement": income_omission,
        "accounts_status_members": account_status,
        "accounts_type_members": account_types,
        "accounting_standard_members": standards,
        "applicable_legislation_members": legislation,
    }

    return {
        "contract_generation": "civic.companieshouse.accounts/0.2",
        "mapping_generation": "companieshouse.ixbrl.frc-2025/0.1",
        "evidence_identity": "CIVIC-DOCUMENT-SHA512:" + sha512,
        "body_sha512": sha512,
        "body_sha256": sha256,
        "source_document_name": path.name,
        "source_content_type": "application/xhtml+xml",
        "company_number": company_number,
        "company_name": company_name,
        "period_start": period_start,
        "period_end": period_end,
        "statement_kind": "ANNUAL_ACCOUNTS",
        "reporting_basis": reporting_basis,
        "units_description": "GBP presentation; source-native fact units retained",
        "filing_identity": f"CH:{company_number}:{period_end}:{filing_date}:{sha256[:16]}",
        "filing_date": filing_date,
        "authorised_at": authorised_at,
        "taxonomy_refs": taxonomy_refs,
        "completeness": completeness,
        "facts": output_facts,
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("input", type=Path)
    ap.add_argument("output", type=Path)
    args = ap.parse_args()
    projection = build_projection(args.input)
    args.output.write_text(json.dumps(projection, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote {len(projection['facts'])} facts to {args.output}")


if __name__ == "__main__":
    main()
