"""Adapter to the *published* ooRexx ConnectSelector 0.1 native object contract.

This module is not a Python reimplementation of selection. To use it, an
application must inject live native ConnectSelector and ConnectIntent access
through its separately configured bidirectional macrospace/embedding bridge.

ConnectSelector~execute(ConnectIntent,payload) -> ConnectResult. The factory
argument ordering follows ConnectIntent~new(operation,mode,requirement,
preferred,destination,options). Passing values through the ooRexx C/API or
an existing native projection is the embedder's responsibility.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable, Mapping

from .errors import ContractError, ProtocolError
from .selection import Invocation


@dataclass(frozen=True)
class ConnectOutcome:
    """Separate selection/result assurances; not a remote Rexx object identity."""
    ok: bool
    provider: str
    accepted: bool
    completed: bool
    durable: bool
    value: Any
    code: str
    detail: str


class ConnectSelectionError(ContractError):
    """A native selector refused/failed execution; preserves the whole result.

    An exception does not imply that the operation had no effects. In
    particular, an ACK_UNCERTAIN result may report accepted=True despite ok=False.
    """
    def __init__(self, outcome: ConnectOutcome):
        self.outcome = outcome
        super().__init__(f"ConnectSelector {outcome.provider or '?'} {outcome.code}: {outcome.detail}")


def _native_get(obj: Any, field: str) -> Any:
    """Default for a Python projection that exposes ooRexx getters as fields."""
    return getattr(obj, field)


def _identity(value: Any) -> Any:
    return value


class NativeConnectSelectorPort:
    """Bind SelectorClient and explicit queue enqueue to ooRexx 0.1 API.

    The injected constructor creates the real native ConnectIntent, *not* a
    Python dict pretending to be an ooRexx object. The host may translate
    its six arguments to ooRexx values. Payload codec must handle e.g. real
    ooRexx Array/Directory, JsonValue and Queue package payloads as needed.

    No provider fallback or retry occurs here. Python does not decide
    selection order or which transport is installed.
    """

    API = 'oorexx.connect_selector/0.1'

    def __init__(self, selector: Any, intent_factory: Callable[..., Any], *,
                 preferred: str = 'AUTO',
                 encode_payload: Callable[[Any], Any] = _identity,
                 decode_value: Callable[[Any], Any] = _identity,
                 read_field: Callable[[Any, str], Any] = _native_get,
                 encode_options: Callable[[Mapping[str, Any]], Any] = _identity,
                 decode_bool: Callable[[Any], bool] = _identity,
                 default_destination: str = '') -> None:
        if not callable(getattr(selector, 'execute', None)):
            raise TypeError('native ConnectSelector projection must expose execute(intent,payload)')
        for name, obj in (('intent_factory', intent_factory), ('encode_payload', encode_payload),
                          ('decode_value', decode_value), ('read_field', read_field),
                          ('encode_options', encode_options), ('decode_bool', decode_bool)):
            if not callable(obj):
                raise TypeError(f'{name} must be callable')
        self._selector = selector
        self._factory = intent_factory
        self._encode = encode_payload
        self._decode = decode_value
        self._read = read_field
        self._options = encode_options
        self._preferred = self._choice(preferred)
        if not isinstance(default_destination, str):
            raise ContractError('default_destination must be a string')
        self._default_destination = default_destination
        self._bool = decode_bool

    @staticmethod
    def _choice(preferred: str) -> str:
        if not isinstance(preferred, str) or preferred.upper() not in ('AUTO', 'DIRECT', 'RPC', 'QUEUE', 'RTO2'):
            raise ContractError('preferred must be AUTO, DIRECT, RPC, QUEUE or RTO2')
        return preferred.upper()

    @staticmethod
    def _outcome(raw: Any, field: Callable[[Any, str], Any],
                 decode_value: Callable[[Any], Any],
                 decode_bool: Callable[[Any], bool] = _identity) -> ConnectOutcome:
        try:
            values = {key: field(raw, key) for key in
                      ('ok', 'provider', 'accepted', 'completed', 'durable', 'value', 'code', 'detail')}
        except (AttributeError, KeyError, TypeError) as exc:
            raise ProtocolError('native ConnectResult is missing a published field') from exc
        for key in ('ok', 'accepted', 'completed', 'durable'):
            values[key] = decode_bool(values[key])
            if type(values[key]) is not bool:
                raise ProtocolError('native ConnectResult boolean flags are invalid')
        if any(not isinstance(values[k], str) for k in ('provider', 'code', 'detail')):
            raise ProtocolError('native ConnectResult provider/code/detail invalid')
        return ConnectOutcome(values['ok'], values['provider'], values['accepted'],
                              values['completed'], values['durable'],
                              decode_value(values['value']), values['code'], values['detail'])

    def _execute(self, operation: str, mode: str, requirement: str,
                 payload: Any, *, preferred: str | None = None,
                 destination: str = '', options: Mapping[str, Any] | None = None) -> ConnectOutcome:
        if not isinstance(operation, str) or not operation:
            raise ContractError('published operation is required')
        if mode not in ('REQUEST', 'NOTIFY', 'ENQUEUE', 'CALLBACK'):
            raise ContractError('unknown ConnectIntent mode')
        if requirement not in ('IMMEDIATE', 'BEST_EFFORT', 'DURABLE', 'CONTINUITY') or (requirement == 'DURABLE' and mode != 'ENQUEUE') or (requirement == 'CONTINUITY' and mode != 'REQUEST'):
            raise ContractError('invalid ConnectIntent guarantee')
        if not isinstance(destination, str):
            raise ContractError('destination must be a string')
        if options is not None and (not isinstance(options, Mapping) or not all(isinstance(k, str) for k in options)):
            raise ContractError('options must be a mapping with string keys')
        # Preserve constructor argument order from ConnectSelector.cls.
        intention = self._factory(operation, mode, requirement, self._choice(preferred or self._preferred),
                                  destination, self._options(dict(options or {})))
        # Once execute begins a failure can be ambiguous. Never retry.
        result = self._selector.execute(intention, self._encode(payload))
        outcome = self._outcome(result, self._read, self._decode, self._bool)
        if not outcome.ok:
            raise ConnectSelectionError(outcome)
        return outcome

    def request(self, invocation: Invocation) -> Any:
        if invocation.kind != 'request':
            raise ContractError('native REQUEST requires a request operation')
        # A published jobs.submit REQUEST returns an authoritative *service*
        # receipt. It is not interchangeable with ConnectSelector ENQUEUE.
        result = self._execute(invocation.operation, 'REQUEST', 'IMMEDIATE', invocation.params,
                               destination=self._default_destination)
        if not result.completed or not result.accepted:
            raise ProtocolError('native REQUEST did not report a completed reply')
        return result.value

    def notify(self, invocation: Invocation) -> None:
        if invocation.kind != 'notification' or invocation.semantics != 'immediate':
            raise ContractError('native NOTIFY requires an immediate notification')
        result = self._execute(invocation.operation, 'NOTIFY', 'IMMEDIATE', invocation.params,
                               destination=self._default_destination)
        if not result.accepted or result.completed or result.durable:
            raise ProtocolError('native NOTIFY has inconsistent acknowledgement flags')
        return None

    def enqueue(self, operation: str, payload: Any, *,
                requirement: str = 'DURABLE', preferred: str = 'AUTO',
                destination: str = '', options: Mapping[str, Any] | None = None) -> ConnectOutcome:
        """Explicit QUEUE enqueue, not a job-service request or RPC result."""
        guarantee = requirement.upper() if isinstance(requirement, str) else ''
        result = self._execute(operation, 'ENQUEUE', guarantee, payload, preferred=preferred,
                               destination=destination, options=options)
        if not result.accepted or result.completed:
            raise ProtocolError('native ENQUEUE has inconsistent acceptance/completion flags')
        if guarantee == 'DURABLE' and not result.durable:
            raise ProtocolError('native ENQUEUE did not confirm requested durability')
        return result

    def callback(self, operation: str, payload: Any, sink: Any, *,
                 preferred: str = 'AUTO', destination: str = '',
                 context: Any = None) -> ConnectOutcome:
        """Local RPC Service Core CALLBACK. Not network streaming.

        Pass a native-visible sink with onNext/onComplete/onFault/isCancelled.
        Encoding ooRexx values and sink lifetime remain the native bridge's job.
        """
        for selector in ('onNext', 'onComplete', 'onFault', 'isCancelled'):
            if not callable(getattr(sink, selector, None)):
                raise ContractError('local callback sink missing ' + selector)
        if self._choice(preferred) not in ('AUTO', 'DIRECT'):
            raise ContractError('CALLBACK is local DIRECT only')
        options = {'callbackSink': sink}
        if context is not None:
            options['context'] = context
        result = self._execute(operation, 'CALLBACK', 'IMMEDIATE', payload,
                               preferred=preferred, destination=destination, options=options)
        if not result.accepted or not result.completed or result.durable or result.provider != 'DIRECT':
            raise ProtocolError('local CALLBACK has inconsistent result semantics')
        return result

    def continuity_request(self, operation: str, payload: Any = None, *,
                           preferred: str = 'AUTO', destination: str = '',
                           options: Mapping[str, Any] | None = None) -> ConnectOutcome:
        """RTO2 continuity request, preserving runtime-owned completion/epoch facts.

        Does not bootstrap RTO2, authorise a runtime, or silently substitute RPC.
        """
        if self._choice(preferred) not in ('AUTO', 'RTO2'):
            raise ContractError('CONTINUITY can only select the RTO2 provider')
        result = self._execute(operation, 'REQUEST', 'CONTINUITY', payload,
                               preferred=preferred, destination=destination, options=options)
        if result.provider != 'RTO2':
            raise ProtocolError('continuity reply not returned by RTO2 authority')
        return result

    def set_observer(self, observer: Any) -> None:
        """Delegate optional dev5 observation to the actual native selector.

        The observer must be projected as a real Rexx-visible object, and native
        ConnectSelector isolates observer exceptions. No Python routing logic.
        """
        if not callable(getattr(self._selector, 'setObserver', None)):
            raise ContractError('native selector does not publish setObserver')
        if observer is not None:
            for name in ('selection', 'outcome'):
                if not callable(getattr(observer, name, None)):
                    raise ContractError('selector observer missing ' + name)
        self._selector.setObserver(observer)

    def explain(self, operation: str, *, mode: str = 'REQUEST',
                requirement: str = 'IMMEDIATE', preferred: str = 'AUTO',
                destination: str = '', options: Mapping[str, Any] | None = None) -> Any:
        """Native ConnectSelector~explain; result format remains bridge-owned."""
        if not callable(getattr(self._selector, 'explain', None)):
            raise ContractError('native selector projection has no explain method')
        if mode not in ('REQUEST', 'NOTIFY', 'ENQUEUE', 'CALLBACK'):
            raise ContractError('invalid explanation mode')
        if requirement not in ('IMMEDIATE', 'BEST_EFFORT', 'DURABLE', 'CONTINUITY') or (requirement == 'DURABLE' and mode != 'ENQUEUE') or (requirement == 'CONTINUITY' and mode != 'REQUEST'):
            raise ContractError('invalid explanation guarantee')
        intent = self._factory(operation, mode, requirement, self._choice(preferred),
                               destination, self._options(dict(options or {})))
        return self._decode(self._selector.explain(intent))
