<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:o="urn:example:orders"
  xmlns:c="urn:example:common">
  <xsl:output method="xml" encoding="UTF-8"/>
  <xsl:template match="/">
    <Summary>
      <OrderCount><xsl:value-of select="count(/o:Orders/o:Order)"/></OrderCount>
      <LineCount><xsl:value-of select="count(/o:Orders/o:Order/o:Line)"/></LineCount>
    </Summary>
  </xsl:template>
</xsl:stylesheet>
