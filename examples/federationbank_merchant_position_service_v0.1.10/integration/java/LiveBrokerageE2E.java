import com.federationbank.atm.brokerage.*;
import com.federationbank.atm.domain.BankSession;
import java.time.Instant;
import java.util.Properties;

public class LiveBrokerageE2E {
  public static void main(String[] args) throws Exception {
    Properties p=new Properties();
    p.setProperty("brokerage.jms.initialContextFactory","org.apache.activemq.jndi.ActiveMQInitialContextFactory");
    p.setProperty("brokerage.jms.providerUrl","tcp://127.0.0.1:61627");
    p.setProperty("brokerage.jms.connectionFactoryJndi","ConnectionFactory");
    p.setProperty("brokerage.jms.requestQueueJndi","dynamicQueues/FB.BROKERAGE.ATM.REQUESTS");
    p.setProperty("brokerage.jms.replyQueueJndi","dynamicQueues/FB.BROKERAGE.ATM.REPLIES.ATM-IOM-001");
    p.setProperty("brokerage.jms.requestTimeoutMillis","10000");
    try (BrokerageService svc=new BrokerageService("ATM-IOM-001",new JndiJmsBrokerageNetwork(p))) {
      BankSession s=new BankSession("SESSION-LIVE-2","CUST-002","Customer Two",Instant.now().plusSeconds(120));
      MerchantPositionSummary m=svc.currentMerchantPosition(s).orElseThrow();
      if(!m.relationshipId().equals("BRK-RET-0002")) throw new AssertionError("relationship");
      if(m.netMarketValueMinor()!=7244000L) throw new AssertionError("market value "+m.netMarketValueMinor());
      if(m.unrealisedPnlMinor()!=321500L) throw new AssertionError("pnl "+m.unrealisedPnlMinor());
      if(m.positionCount()!=2) throw new AssertionError("positions");
      if(!m.sourceAuthority().equals("FEDERATION_BROKERAGE_POSITION_AUTHORITY")) throw new AssertionError("authority");
      System.out.println("JAVA ATM BROKERAGE REAL JMS PASS relationship="+m.relationshipId()+" marketValue="+m.netMarketValueMinor()+" positions="+m.positionCount());
    }
  }
}
