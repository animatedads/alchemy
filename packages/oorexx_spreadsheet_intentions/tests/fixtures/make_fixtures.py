from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parent


def write_zip(path, members):
    with ZipFile(path, 'w', ZIP_DEFLATED) as z:
        for name, text in members.items():
            z.writestr(name, text)


xlsx = {
    '[Content_Types].xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/xl/worksheets/sheet3.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>''',
    '_rels/.rels': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''',
    'xl/workbook.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets><sheet name="Customers" sheetId="1" r:id="rId1"/><sheet name="Ledger" sheetId="2" r:id="rId2"/><sheet name="Orders" sheetId="3" r:id="rId5"/></sheets>
</workbook>''',
    'xl/_rels/workbook.xml.rels': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
<Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
<Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet3.xml"/>
</Relationships>''',
    'xl/sharedStrings.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="24" uniqueCount="20">
<si><t>Customer ID</t></si><si><t>Name</t></si><si><t>City</t></si><si><t>Credit Limit</t></si><si><t>Active</t></si>
<si><t>Alice Morgan</t></si><si><t>Rochdale</t></si><si><t>Bob Smith</t></si><si><t>Manchester</t></si><si><t>Jane Smith</t></si>
<si><t>Amount</t></si><si><t>Text Amount</t></si><si><t>Formula Total</t></si><si><t>$1000</t></si><si><t>Notes</t></si>
<si><t>literal currency-looking text</t></si><si><t>real numeric currency</t></si><si><t>mixed column</t></si><si><t>1000</t></si><si><t>not a number</t></si>
</sst>''',
    'xl/styles.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<numFmts count="1"><numFmt numFmtId="164" formatCode="$#,##0.00"/></numFmts>
<fonts count="1"><font/></fonts><fills count="1"><fill/></fills><borders count="1"><border/></borders>
<cellStyleXfs count="1"><xf numFmtId="0"/></cellStyleXfs>
<cellXfs count="2"><xf numFmtId="0"/><xf numFmtId="164" applyNumberFormat="1"/></cellXfs>
</styleSheet>''',
    'xl/worksheets/sheet1.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>
<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="C1" t="s"><v>2</v></c><c r="D1" t="s"><v>3</v></c><c r="E1" t="s"><v>4</v></c></row>
<row r="2"><c r="A2"><v>1</v></c><c r="B2" t="s"><v>5</v></c><c r="C2" t="s"><v>6</v></c><c r="D2" s="1"><v>2500</v></c><c r="E2" t="b"><v>1</v></c></row>
<row r="3"><c r="A3"><v>2</v></c><c r="B3" t="s"><v>7</v></c><c r="C3" t="s"><v>8</v></c><c r="D3" s="1"><v>1000</v></c><c r="E3" t="b"><v>1</v></c></row>
<row r="4"><c r="A4"><v>3</v></c><c r="B4" t="s"><v>9</v></c><c r="C4" t="s"><v>6</v></c><c r="D4" s="1"><v>750</v></c><c r="E4" t="b"><v>0</v></c></row>
</sheetData></worksheet>''',
    'xl/worksheets/sheet2.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>
<row r="1"><c r="A1" t="s"><v>10</v></c><c r="B1" t="s"><v>11</v></c><c r="C1" t="s"><v>12</v></c><c r="D1" t="s"><v>14</v></c></row>
<row r="2"><c r="A2" s="1"><v>1000</v></c><c r="B2" t="s"><v>13</v></c><c r="C2"><f>SUM(A2:A3)</f><v>3000</v></c><c r="D2" t="s"><v>16</v></c></row>
<row r="3"><c r="A3" s="1"><v>2000</v></c><c r="B3" t="s"><v>18</v></c><c r="C3"><f>SUM(A2:A3)</f><v>3000</v></c><c r="D3" t="s"><v>17</v></c></row>
<row r="4"><c r="A4" t="s"><v>18</v></c><c r="B4" t="s"><v>19</v></c><c r="D4" t="s"><v>15</v></c></row>
</sheetData></worksheet>''',
    'xl/worksheets/sheet3.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>
<row r="1"><c r="A1" t="inlineStr"><is><t>Order ID</t></is></c><c r="B1" t="inlineStr"><is><t>Customer ID</t></is></c><c r="C1" t="inlineStr"><is><t>Amount</t></is></c><c r="D1" t="inlineStr"><is><t>Status</t></is></c></row>
<row r="2"><c r="A2"><v>101</v></c><c r="B2"><v>1</v></c><c r="C2" s="1"><v>125</v></c><c r="D2" t="inlineStr"><is><t>OPEN</t></is></c></row>
<row r="3"><c r="A3"><v>102</v></c><c r="B3"><v>2</v></c><c r="C3" s="1"><v>250</v></c><c r="D3" t="inlineStr"><is><t>PAID</t></is></c></row>
<row r="4"><c r="A4"><v>103</v></c><c r="B4"><v>3</v></c><c r="C4" s="1"><v>75</v></c><c r="D4" t="inlineStr"><is><t>OPEN</t></is></c></row>
<row r="5"><c r="A5"><v>104</v></c><c r="B5"><v>1</v></c><c r="C5" s="1"><v>50</v></c><c r="D5" t="inlineStr"><is><t>PAID</t></is></c></row>
</sheetData></worksheet>''',
}
write_zip(ROOT / 'nasty.xlsx', xlsx)

ods_content = '''<?xml version="1.0" encoding="UTF-8"?>
<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" office:version="1.3">
<office:body><office:spreadsheet>
<table:table table:name="Customers">
<table:table-row><table:table-cell office:value-type="string"><text:p>Customer ID</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Name</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>City</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Credit Limit</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Active</text:p></table:table-cell></table:table-row>
<table:table-row><table:table-cell office:value-type="float" office:value="1"><text:p>1</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Alice Morgan</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Rochdale</text:p></table:table-cell><table:table-cell office:value-type="currency" office:value="2500" office:currency="GBP"><text:p>£2,500.00</text:p></table:table-cell><table:table-cell office:value-type="boolean" office:boolean-value="true"><text:p>TRUE</text:p></table:table-cell></table:table-row>
<table:table-row><table:table-cell office:value-type="float" office:value="2"><text:p>2</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Bob Smith</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Manchester</text:p></table:table-cell><table:table-cell office:value-type="currency" office:value="1000" office:currency="GBP"><text:p>£1,000.00</text:p></table:table-cell><table:table-cell office:value-type="boolean" office:boolean-value="true"><text:p>TRUE</text:p></table:table-cell></table:table-row>
<table:table-row><table:table-cell office:value-type="float" office:value="3"><text:p>3</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Jane Smith</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Rochdale</text:p></table:table-cell><table:table-cell office:value-type="currency" office:value="750" office:currency="GBP"><text:p>£750.00</text:p></table:table-cell><table:table-cell office:value-type="boolean" office:boolean-value="false"><text:p>FALSE</text:p></table:table-cell></table:table-row>
</table:table>
<table:table table:name="Ledger">
<table:table-row><table:table-cell office:value-type="string"><text:p>Amount</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Text Amount</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Formula Total</text:p></table:table-cell></table:table-row>
<table:table-row><table:table-cell office:value-type="currency" office:value="1000" office:currency="GBP"><text:p>£1,000.00</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>$1000</text:p></table:table-cell><table:table-cell table:formula="of:=SUM([.A2:.A3])" office:value-type="float" office:value="3000"><text:p>3000</text:p></table:table-cell></table:table-row>
<table:table-row><table:table-cell office:value-type="currency" office:value="2000" office:currency="GBP"><text:p>£2,000.00</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>1000</text:p></table:table-cell><table:table-cell table:formula="of:=SUM([.A2:.A3])" office:value-type="float" office:value="3000"><text:p>3000</text:p></table:table-cell></table:table-row>
<table:table-row table:number-rows-repeated="1048474"><table:table-cell table:number-columns-repeated="1024"/></table:table-row>
</table:table>
<table:table table:name="Orders">
<table:table-row><table:table-cell office:value-type="string"><text:p>Order ID</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Customer ID</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Amount</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Status</text:p></table:table-cell></table:table-row>
<table:table-row><table:table-cell office:value-type="float" office:value="101"><text:p>101</text:p></table:table-cell><table:table-cell office:value-type="float" office:value="1"><text:p>1</text:p></table:table-cell><table:table-cell office:value-type="currency" office:value="125" office:currency="GBP"><text:p>£125.00</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>OPEN</text:p></table:table-cell></table:table-row>
<table:table-row><table:table-cell office:value-type="float" office:value="102"><text:p>102</text:p></table:table-cell><table:table-cell office:value-type="float" office:value="2"><text:p>2</text:p></table:table-cell><table:table-cell office:value-type="currency" office:value="250" office:currency="GBP"><text:p>£250.00</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>PAID</text:p></table:table-cell></table:table-row>
<table:table-row><table:table-cell office:value-type="float" office:value="103"><text:p>103</text:p></table:table-cell><table:table-cell office:value-type="float" office:value="3"><text:p>3</text:p></table:table-cell><table:table-cell office:value-type="currency" office:value="75" office:currency="GBP"><text:p>£75.00</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>OPEN</text:p></table:table-cell></table:table-row>
<table:table-row><table:table-cell office:value-type="float" office:value="104"><text:p>104</text:p></table:table-cell><table:table-cell office:value-type="float" office:value="1"><text:p>1</text:p></table:table-cell><table:table-cell office:value-type="currency" office:value="50" office:currency="GBP"><text:p>£50.00</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>PAID</text:p></table:table-cell></table:table-row>
</table:table>

</office:spreadsheet></office:body></office:document-content>'''
ods = {
    'mimetype': 'application/vnd.oasis.opendocument.spreadsheet',
    'content.xml': ods_content,
    'META-INF/manifest.xml': '''<?xml version="1.0" encoding="UTF-8"?><manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.3"><manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.spreadsheet"/><manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/></manifest:manifest>'''
}
write_zip(ROOT / 'nasty.ods', ods)

regions_xlsx = {
    '[Content_Types].xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>''',
    '_rels/.rels': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>''',
    'xl/workbook.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Operational Data" sheetId="1" r:id="rId1"/></sheets></workbook>''',
    'xl/_rels/workbook.xml.rels': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>''',
    'xl/worksheets/sheet1.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>
<row r="1"><c r="A1" t="inlineStr"><is><t>Customer ID</t></is></c><c r="B1" t="inlineStr"><is><t>Name</t></is></c><c r="C1" t="inlineStr"><is><t>City</t></is></c><c r="D1" t="inlineStr"><is><t>Credit Limit</t></is></c></row>
<row r="2"><c r="A2"><v>1</v></c><c r="B2" t="inlineStr"><is><t>Alice Morgan</t></is></c><c r="C2" t="inlineStr"><is><t>Rochdale</t></is></c><c r="D2"><v>2500</v></c></row>
<row r="3"><c r="A3"><v>2</v></c><c r="B3" t="inlineStr"><is><t>Bob Smith</t></is></c><c r="C3" t="inlineStr"><is><t>Manchester</t></is></c><c r="D3"><v>1000</v></c></row>
<row r="4"><c r="A4"><v>3</v></c><c r="B4" t="inlineStr"><is><t>Jane Smith</t></is></c><c r="C4" t="inlineStr"><is><t>Rochdale</t></is></c><c r="D4"><v>750</v></c></row>
<row r="5"><c r="A5" t="inlineStr"><is><t>TOTAL</t></is></c><c r="D5"><f>SUM(D2:D4)</f><v>4250</v></c></row>
<row r="8"><c r="A8" t="inlineStr"><is><t>Order ID</t></is></c><c r="B8" t="inlineStr"><is><t>Customer ID</t></is></c><c r="C8" t="inlineStr"><is><t>Amount</t></is></c><c r="D8" t="inlineStr"><is><t>Status</t></is></c></row>
<row r="9"><c r="A9"><v>101</v></c><c r="B9"><v>1</v></c><c r="C9"><v>125</v></c><c r="D9" t="inlineStr"><is><t>OPEN</t></is></c></row>
<row r="10"><c r="A10"><v>102</v></c><c r="B10"><v>2</v></c><c r="C10"><v>250</v></c><c r="D10" t="inlineStr"><is><t>PAID</t></is></c></row>
<row r="11"><c r="A11"><v>103</v></c><c r="B11"><v>3</v></c><c r="C11"><v>75</v></c><c r="D11" t="inlineStr"><is><t>OPEN</t></is></c></row>
<row r="12"><c r="A12"><v>104</v></c><c r="B12"><v>1</v></c><c r="C12"><v>50</v></c><c r="D12" t="inlineStr"><is><t>PAID</t></is></c></row>
<row r="13"><c r="A13" t="inlineStr"><is><t>GRAND TOTAL</t></is></c><c r="C13"><f>SUM(C9:C12)</f><v>500</v></c></row>
</sheetData></worksheet>''',
}
write_zip(ROOT / 'regions.xlsx', regions_xlsx)

regions_ods_content = '''<?xml version="1.0" encoding="UTF-8"?>
<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" office:version="1.3">
<office:body><office:spreadsheet><table:table table:name="Operational Data">
<table:table-row><table:table-cell office:value-type="string"><text:p>Customer ID</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Name</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>City</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Credit Limit</text:p></table:table-cell></table:table-row>
<table:table-row><table:table-cell office:value-type="float" office:value="1"><text:p>1</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Alice Morgan</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Rochdale</text:p></table:table-cell><table:table-cell office:value-type="float" office:value="2500"><text:p>2500</text:p></table:table-cell></table:table-row>
<table:table-row><table:table-cell office:value-type="float" office:value="2"><text:p>2</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Bob Smith</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Manchester</text:p></table:table-cell><table:table-cell office:value-type="float" office:value="1000"><text:p>1000</text:p></table:table-cell></table:table-row>
<table:table-row><table:table-cell office:value-type="float" office:value="3"><text:p>3</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Jane Smith</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Rochdale</text:p></table:table-cell><table:table-cell office:value-type="float" office:value="750"><text:p>750</text:p></table:table-cell></table:table-row>
<table:table-row><table:table-cell office:value-type="string"><text:p>TOTAL</text:p></table:table-cell><table:table-cell/><table:table-cell/><table:table-cell table:formula="of:=SUM([.D2:.D4])" office:value-type="float" office:value="4250"><text:p>4250</text:p></table:table-cell></table:table-row>
<table:table-row/>
<table:table-row/>
<table:table-row><table:table-cell office:value-type="string"><text:p>Order ID</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Customer ID</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Amount</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>Status</text:p></table:table-cell></table:table-row>
<table:table-row><table:table-cell office:value-type="float" office:value="101"><text:p>101</text:p></table:table-cell><table:table-cell office:value-type="float" office:value="1"><text:p>1</text:p></table:table-cell><table:table-cell office:value-type="float" office:value="125"><text:p>125</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>OPEN</text:p></table:table-cell></table:table-row>
<table:table-row><table:table-cell office:value-type="float" office:value="102"><text:p>102</text:p></table:table-cell><table:table-cell office:value-type="float" office:value="2"><text:p>2</text:p></table:table-cell><table:table-cell office:value-type="float" office:value="250"><text:p>250</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>PAID</text:p></table:table-cell></table:table-row>
<table:table-row><table:table-cell office:value-type="float" office:value="103"><text:p>103</text:p></table:table-cell><table:table-cell office:value-type="float" office:value="3"><text:p>3</text:p></table:table-cell><table:table-cell office:value-type="float" office:value="75"><text:p>75</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>OPEN</text:p></table:table-cell></table:table-row>
<table:table-row><table:table-cell office:value-type="float" office:value="104"><text:p>104</text:p></table:table-cell><table:table-cell office:value-type="float" office:value="1"><text:p>1</text:p></table:table-cell><table:table-cell office:value-type="float" office:value="50"><text:p>50</text:p></table:table-cell><table:table-cell office:value-type="string"><text:p>PAID</text:p></table:table-cell></table:table-row>
<table:table-row><table:table-cell office:value-type="string"><text:p>GRAND TOTAL</text:p></table:table-cell><table:table-cell/><table:table-cell table:formula="of:=SUM([.C9:.C12])" office:value-type="float" office:value="500"><text:p>500</text:p></table:table-cell></table:table-row>
</table:table></office:spreadsheet></office:body></office:document-content>'''
regions_ods = {
    'mimetype': 'application/vnd.oasis.opendocument.spreadsheet',
    'content.xml': regions_ods_content,
    'META-INF/manifest.xml': '''<?xml version="1.0" encoding="UTF-8"?><manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.3"><manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.spreadsheet"/><manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/></manifest:manifest>'''
}
write_zip(ROOT / 'regions.ods', regions_ods)
