package com.federationbank.atm.brokerage;

import javax.naming.Context;
import javax.naming.InitialContext;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.Hashtable;
import java.util.Properties;

/** Separate broker-neutral JMS request/reply transport for the brokerage source. */
public final class JndiJmsBrokerageNetwork implements BrokerageNetwork {
    private final Properties config;
    private volatile boolean online;
    public JndiJmsBrokerageNetwork(Properties config){this.config=config;}
    @Override public boolean isOnline(){return online;}

    @Override public BrokerageResponse exchange(BrokerageRequest request) throws BrokerageNetworkException {
        Object connection=null,session=null,producer=null,consumer=null; InitialContext context=null;
        try {
            context=context();
            Object factory=context.lookup(required("brokerage.jms.connectionFactoryJndi"));
            Object requestQueue=context.lookup(required("brokerage.jms.requestQueueJndi"));
            Object replyQueue=context.lookup(required("brokerage.jms.replyQueueJndi"));
            connection=createConnection(factory);
            session=Reflect.call(connection,"createSession",false,1);
            producer=Reflect.call(session,"createProducer",requestQueue);
            consumer=Reflect.call(session,"createConsumer",replyQueue,"JMSCorrelationID = '"+selectorSafe(request.commandId())+"'");
            Object message=Reflect.call(session,"createTextMessage",request.toJson());
            Reflect.call(message,"setJMSCorrelationID",request.commandId()); Reflect.call(message,"setJMSReplyTo",replyQueue);
            Reflect.call(message,"setStringProperty","FB_BROKERAGE_SCHEMA",request.schema());
            Reflect.call(message,"setStringProperty","FB_BROKERAGE_OPERATION",request.operation());
            Reflect.call(message,"setStringProperty","FB_ATM_TERMINAL_ID",request.terminalId());
            Reflect.call(connection,"start"); Reflect.call(producer,"send",message);
            long timeout=Long.parseLong(config.getProperty("brokerage.jms.requestTimeoutMillis","10000"));
            Object incoming=Reflect.call(consumer,"receive",timeout);
            if(incoming==null) throw new BrokerageNetworkException("brokerage JMS response timeout for "+request.commandId());
            String correlation=String.valueOf(Reflect.call(incoming,"getJMSCorrelationID"));
            if(!request.commandId().equals(correlation)) throw new BrokerageNetworkException("brokerage JMS correlation mismatch");
            BrokerageResponse r=BrokerageResponse.fromJson(String.valueOf(Reflect.call(incoming,"getText")));
            online=true; return r;
        } catch(BrokerageNetworkException e){online=false;throw e;} catch(Exception e){online=false;throw new BrokerageNetworkException("brokerage JMS exchange failed: "+rootMessage(e),e);}
        finally {closeQuietly(consumer);closeQuietly(producer);closeQuietly(session);closeQuietly(connection);if(context!=null)try{context.close();}catch(Exception ignored){}}
    }

    private InitialContext context() throws Exception {
        Hashtable<String,String> env=new Hashtable<>();
        String factory=config.getProperty("brokerage.jms.initialContextFactory",config.getProperty("jms.initialContextFactory","")).trim();
        String url=config.getProperty("brokerage.jms.providerUrl",config.getProperty("jms.providerUrl","")).trim();
        if(!factory.isEmpty())env.put(Context.INITIAL_CONTEXT_FACTORY,factory); if(!url.isEmpty())env.put(Context.PROVIDER_URL,url);
        return env.isEmpty()?new InitialContext():new InitialContext(env);
    }
    private Object createConnection(Object factory)throws Exception{
        String username=config.getProperty("brokerage.jms.username","").trim();
        String passwordEnv=config.getProperty("brokerage.jms.passwordEnv","").trim();
        String password=passwordEnv.isEmpty()?"":System.getenv(passwordEnv);
        if(!username.isEmpty()){if(password==null)throw new BrokerageNetworkException("brokerage JMS password environment variable is not set: "+passwordEnv);return Reflect.call(factory,"createConnection",username,password);}
        return Reflect.call(factory,"createConnection");
    }
    private String required(String key)throws BrokerageNetworkException{String v=config.getProperty(key,"").trim();if(v.isEmpty())throw new BrokerageNetworkException("missing configuration: "+key);return v;}
    private static String selectorSafe(String s){return s.replace("'","''");}
    private static void closeQuietly(Object x){if(x!=null)try{Reflect.call(x,"close");}catch(Exception ignored){}}
    private static String rootMessage(Throwable e){Throwable t=e;while(t instanceof InvocationTargetException x&&x.getCause()!=null)t=x.getCause();return t.getMessage()==null?t.getClass().getSimpleName():t.getMessage();}
    static final class Reflect{
        static Object call(Object target,String name,Object...args)throws Exception{Method best=null;for(Method m:target.getClass().getMethods()){if(!m.getName().equals(name)||m.getParameterCount()!=args.length)continue;Class<?>[]types=m.getParameterTypes();boolean ok=true;for(int i=0;i<types.length;i++)if(!compatible(types[i],args[i])){ok=false;break;}if(ok){best=m;break;}}if(best==null)throw new NoSuchMethodException(target.getClass().getName()+"."+name+"/"+args.length);return best.invoke(target,args);}
        private static boolean compatible(Class<?>t,Object a){if(a==null)return!t.isPrimitive();if(!t.isPrimitive())return t.isInstance(a)||t.isAssignableFrom(a.getClass());return(t==boolean.class&&a instanceof Boolean)||(t==int.class&&a instanceof Integer)||(t==long.class&&a instanceof Long);}
    }
}
