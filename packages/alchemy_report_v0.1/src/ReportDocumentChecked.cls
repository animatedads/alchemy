/******************************************************************************/
/* Report document with maths + crypto-check mixins mixed in.                 */
/* Use this when the report must add and verify; core ReportDocument stays    */
/* free of those behaviours.                                                  */
/******************************************************************************/
::class ReportDocumentChecked public subclass ReportDocument inherit ReportMathsMixin ReportCryptoCheckMixin

::requires "AlchemyReport.cls"
::requires "mixins/ReportMathsMixin.cls"
::requires "mixins/ReportCryptoCheckMixin.cls"
