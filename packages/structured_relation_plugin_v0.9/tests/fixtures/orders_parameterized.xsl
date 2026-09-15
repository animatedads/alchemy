<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:o="urn:example:orders"
  xmlns:c="urn:example:common">
  <xsl:param name="label" select="'default label'"/>
  <xsl:template match="/">
    <Summary>
      <Label><xsl:value-of select="$label"/></Label>
      <OrderCount><xsl:value-of select="count(/o:Orders/o:Order)"/></OrderCount>
      <FirstBuyer><xsl:value-of select="/o:Orders/o:Order[1]/c:Buyer"/></FirstBuyer>
    </Summary>
  </xsl:template>
</xsl:stylesheet>
