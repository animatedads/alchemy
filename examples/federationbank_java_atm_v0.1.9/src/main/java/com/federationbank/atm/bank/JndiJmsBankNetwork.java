package com.federationbank.atm.bank;

import com.federationbank.atm.protocol.BankRequest;
import com.federationbank.atm.protocol.BankResponse;

import javax.naming.Context;
import javax.naming.InitialContext;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.Hashtable;
import java.util.Properties;

/**
 * Broker-neutral JMS request/reply transport using JNDI and reflection.
 *
 * Why reflection? JMS provider API classes are intentionally not bundled with this demo.
 * A provider's javax.jms or jakarta.jms client jar may be placed on the runtime classpath;
 * this class then drives the standard JMS 1.1-compatible methods without tying the ATM
 * source tree to one broker or one JMS package namespace.
 */
public final class JndiJmsBankNetwork implements BankNetwork {
    private final Properties config;
    private volatile boolean online;

    public JndiJmsBankNetwork(Properties config) { this.config = config; }
    @Override public boolean isOnline() { return online; }

    @Override
    public BankResponse exchange(BankRequest request) throws BankNetworkException {
        Object connection = null, session = null, producer = null, consumer = null;
        InitialContext context = null;
        try {
            context = context();
            Object factory = context.lookup(required("jms.connectionFactoryJndi"));
            Object requestQueue = context.lookup(required("jms.requestQueueJndi"));
            Object replyQueue = context.lookup(required("jms.replyQueueJndi"));
            connection = createConnection(factory);
            session = Reflect.call(connection, "createSession", false, 1); // AUTO_ACKNOWLEDGE
            producer = Reflect.call(session, "createProducer", requestQueue);
            String selector = "JMSCorrelationID = '" + selectorSafe(request.commandId()) + "'";
            consumer = Reflect.call(session, "createConsumer", replyQueue, selector);
            Object message = Reflect.call(session, "createTextMessage", request.toJson());
            Reflect.call(message, "setJMSCorrelationID", request.commandId());
            Reflect.call(message, "setJMSReplyTo", replyQueue);
            Reflect.call(message, "setStringProperty", "FB_ATM_SCHEMA", request.schema());
            Reflect.call(message, "setStringProperty", "FB_ATM_OPERATION", request.operation());
            Reflect.call(message, "setStringProperty", "FB_ATM_TERMINAL_ID", request.terminalId());
            Reflect.call(message, "setLongProperty", "FB_ATM_RULES_VERSION", request.rulesVersion());
            Reflect.call(connection, "start");
            Reflect.call(producer, "send", message);
            long timeout = Long.parseLong(config.getProperty("jms.requestTimeoutMillis", "10000"));
            Object incoming = Reflect.call(consumer, "receive", timeout);
            if (incoming == null) throw new BankNetworkException("JMS response timeout for " + request.commandId());
            String correlation = String.valueOf(Reflect.call(incoming, "getJMSCorrelationID"));
            if (!request.commandId().equals(correlation)) throw new BankNetworkException("JMS correlation mismatch");
            String json = String.valueOf(Reflect.call(incoming, "getText"));
            BankResponse response = BankResponse.fromJson(json);
            if (!request.commandId().equals(response.commandId())) throw new BankNetworkException("payload commandId mismatch");
            online = true;
            return response;
        } catch (BankNetworkException e) {
            online = false;
            throw e;
        } catch (Exception e) {
            online = false;
            throw new BankNetworkException("JMS exchange failed: " + rootMessage(e), e);
        } finally {
            closeQuietly(consumer); closeQuietly(producer); closeQuietly(session); closeQuietly(connection);
            if (context != null) try { context.close(); } catch (Exception ignored) {}
        }
    }

    @Override
    public BankResponse pollRuleUpdate(long timeoutMillis) throws BankNetworkException {
        String topicName = config.getProperty("jms.rulesTopicJndi", "").trim();
        if (topicName.isEmpty()) return null;
        Object connection = null, session = null, consumer = null;
        InitialContext context = null;
        try {
            context = context();
            Object factory = context.lookup(required("jms.connectionFactoryJndi"));
            Object topic = context.lookup(topicName);
            connection = createConnection(factory);
            String clientId = config.getProperty("atm.terminalId", "ATM-UNKNOWN") + "-RULES";
            Reflect.call(connection, "setClientID", clientId);
            session = Reflect.call(connection, "createSession", false, 1);
            String subscription = config.getProperty("jms.durableSubscriptionName", clientId);
            consumer = Reflect.call(session, "createDurableSubscriber", topic, subscription);
            Reflect.call(connection, "start");
            Object incoming = Reflect.call(consumer, "receive", Math.max(0L, timeoutMillis));
            if (incoming == null) return null;
            String json = String.valueOf(Reflect.call(incoming, "getText"));
            online = true;
            return BankResponse.fromJson(json);
        } catch (Exception e) {
            online = false;
            throw new BankNetworkException("JMS rules subscription failed: " + rootMessage(e), e);
        } finally {
            closeQuietly(consumer); closeQuietly(session); closeQuietly(connection);
            if (context != null) try { context.close(); } catch (Exception ignored) {}
        }
    }

    private InitialContext context() throws Exception {
        Hashtable<String, String> env = new Hashtable<>();
        String factory = config.getProperty("jms.initialContextFactory", "").trim();
        String url = config.getProperty("jms.providerUrl", "").trim();
        if (!factory.isEmpty()) env.put(Context.INITIAL_CONTEXT_FACTORY, factory);
        if (!url.isEmpty()) env.put(Context.PROVIDER_URL, url);
        return env.isEmpty() ? new InitialContext() : new InitialContext(env);
    }

    private Object createConnection(Object factory) throws Exception {
        String username = config.getProperty("jms.username", "").trim();
        String passwordEnv = config.getProperty("jms.passwordEnv", "").trim();
        String password = passwordEnv.isEmpty() ? "" : System.getenv(passwordEnv);
        if (!username.isEmpty()) {
            if (password == null) throw new BankNetworkException("JMS password environment variable is not set: " + passwordEnv);
            return Reflect.call(factory, "createConnection", username, password);
        }
        return Reflect.call(factory, "createConnection");
    }

    private String required(String key) throws BankNetworkException {
        String value = config.getProperty(key, "").trim();
        if (value.isEmpty()) throw new BankNetworkException("missing configuration: " + key);
        return value;
    }

    private static String selectorSafe(String s) { return s.replace("'", "''"); }
    private static void closeQuietly(Object target) { if (target != null) try { Reflect.call(target, "close"); } catch (Exception ignored) {} }
    private static String rootMessage(Throwable e) {
        Throwable t = e;
        while (t instanceof InvocationTargetException x && x.getCause() != null) t = x.getCause();
        return t.getMessage() == null ? t.getClass().getSimpleName() : t.getMessage();
    }

    static final class Reflect {
        private Reflect() {}
        static Object call(Object target, String name, Object... args) throws Exception {
            Method best = null;
            for (Method m : target.getClass().getMethods()) {
                if (!m.getName().equals(name) || m.getParameterCount() != args.length) continue;
                Class<?>[] types = m.getParameterTypes();
                boolean compatible = true;
                for (int i = 0; i < types.length; i++) if (!compatible(types[i], args[i])) { compatible = false; break; }
                if (compatible) { best = m; break; }
            }
            if (best == null) throw new NoSuchMethodException(target.getClass().getName() + "." + name + "/" + args.length);
            return best.invoke(target, args);
        }
        private static boolean compatible(Class<?> type, Object arg) {
            if (arg == null) return !type.isPrimitive();
            if (!type.isPrimitive()) return type.isInstance(arg) || type.isAssignableFrom(arg.getClass());
            return (type == boolean.class && arg instanceof Boolean)
                    || (type == int.class && arg instanceof Integer)
                    || (type == long.class && arg instanceof Long)
                    || (type == double.class && arg instanceof Double)
                    || (type == float.class && arg instanceof Float)
                    || (type == short.class && arg instanceof Short)
                    || (type == byte.class && arg instanceof Byte)
                    || (type == char.class && arg instanceof Character);
        }
    }
}
