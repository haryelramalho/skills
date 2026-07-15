# Salesmart Fixtures and Factories

## Contents

- [Factory Location](#factory-location)
- [Factory Signature](#factory-signature)
- [Promotion Rule](#promotion-rule)
- [Canonical Auth and Session Fixtures](#canonical-auth-and-session-fixtures)
- [Conftest Policy](#conftest-policy)

## Factory Location

Keep feature-specific factories in `tests/utils/<feature>/factories.py`. Keep thin pytest fixture wrappers in `tests/utils/<feature>/fixtures.py`.

Do not create an empty utility package in anticipation of reuse. Promote only after real reuse appears.

## Factory Signature

Use this async SQLAlchemy shape for model factories:

```python
async def create_<model>(
    session: AsyncSession,
    *,
    <model>_id: UUID | None = None,
    **overrides: object,
) -> <ModelType>:
    instance = <ModelType>(
        id=<model>_id or uuid4(),
        **{**DEFAULTS, **overrides},
    )
    session.add(instance)
    await session.flush()
    return instance
```

Salesmart factory rules:

- Use keyword-only overrides.
- Accept deterministic IDs when reproducible UUIDs matter.
- Use plausible defaults.
- Flush and return the model.
- Do not commit; the test or fixture owns the transaction.

## Promotion Rule

Promote a factory to `tests/utils/common/factories.py` only when two or more feature areas actually consume it.

Current common factories:

- `create_hotel`
- `create_company`

Keep all other factories feature-local until reuse is confirmed.

## Canonical Auth and Session Fixtures

Keep these auth/session fixtures in `tests/conftest.py` rather than duplicating them in `tests/utils/auth/`:

- `create_test_user`
- `create_authenticated_session`
- `authenticated_admin`
- `authenticated_manager`
- `mock_user`
- `mock_admin_user`
- `password_hasher`
- `password_spec`
- `session_store`
- `login_tracker`
- `user_repository`
- `test_email_gateway`
- `fake_redis`

## Conftest Policy

Remove feature-local conftests when they duplicate global fixtures. The known remaining local integration conftest is `tests/integration/infra/adapters/conftest.py` because it shares commission reader seeds across multiple readers.
