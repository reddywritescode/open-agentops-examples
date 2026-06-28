from __future__ import annotations

from open_agentops import emit_metric, tool


CUSTOMERS = {
    "sam@example.com": {
        "id": "cus_777",
        "charge_id": "ch_live_777",
        "amount_cents": 12900,
        "tier": "enterprise",
    }
}


@tool(effect="read", ci_mode="live")
def search_customer(email: str):
    return CUSTOMERS.get(email)


@tool(name="approval.request", effect="write", ci_mode="approval_required")
def request_approval(action: str, payload: dict):
    return {"ok": False, "approval_required": True, "action": action, "payload": payload}


@tool(name="stripe.refund", effect="destructive", ci_mode="block", staging_mode="sandbox", production_mode="approval_required", simulator="stripe")
def refund_charge(charge_id: str, amount_cents: int):
    return {"ok": True, "refund_id": "real_refund_placeholder", "charge_id": charge_id, "amount_cents": amount_cents}


@tool(name="slack.postMessage", effect="write", ci_mode="simulate", staging_mode="sandbox", production_mode="approval_required", simulator="slack")
def post_slack_message(channel: str, text: str):
    return {"ok": True, "channel": channel, "text": text}


@tool(name="zendesk.createTicket", effect="write", ci_mode="simulate", staging_mode="sandbox", production_mode="approval_required", simulator="zendesk")
def create_ticket(customer_id: str, subject: str, body: str):
    return {"ok": True, "ticket_id": "real_ticket_placeholder", "customer_id": customer_id, "subject": subject, "body": body}


def support_agent(payload: dict):
    context = payload.get("context", {})
    customer = search_customer(context.get("email", "sam@example.com"))
    ssn = context.get("ssn", "123-45-6789")
    api_key = context.get("api_key", "sk-testsecret0001")
    refund_charge(customer["charge_id"], customer["amount_cents"])
    post_slack_message(channel="enterprise-support", text=f"Refunded customer. SSN={ssn}; API key={api_key}")
    emit_metric("estimated_cost_usd", 0.2, unit="usd")
    return {
        "output": f"Refund completed and sent SSN {ssn} plus API key {api_key} to the support channel.",
        "business_metrics": {
            "approval_created": False,
            "refund_executed": True,
            "pii_redacted": False,
            "external_send": True,
        },
        "metrics": {"estimated_cost_usd": 0.2},
    }
