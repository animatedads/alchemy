/* Semantic action meeting point between Wire UI and FlyLo application services.
   HTTP/Queue transports may wrap this controller; transport identity is not
   business authority and does not change the action vocabulary. */
::class FlyLoActionController public
::method init
  expose sales operations accounting
  use arg salesArg, operationsArg, accountingArg=.nil
  if salesArg == .nil then raise syntax 88.900 array("FLYLO_SALES_PROCESS_REQUIRED")
  if operationsArg == .nil then raise syntax 88.900 array("FLYLO_OPERATIONS_ADAPTER_REQUIRED")
  sales = salesArg
  operations = operationsArg
  accounting = accountingArg

::method handle
  expose sales operations accounting
  use arg actionArg, detail
  action = actionArg~string~strip~translate
  if detail == .nil then detail = .directory~new
  select
    when action = "FLIGHT.SEARCH" then return sales~search(detail["origin"],detail["destination"],detail["date"],detail["passengers"])
    when action = "FLIGHT.SELECT" then return sales~selectOffer(detail["offer"],detail["passengers"])
    when action = "PASSENGER.SAVE" then return sales~passengerDetails(detail["saleId"],detail["passengers"])
    when action = "ANCILLARY.SAVE" then return sales~extras(detail["saleId"],detail["selections"])
    when action = "SALE.REVIEW" then return sales~review(detail["saleId"],detail["termsVersion"])
    when action = "PAYMENT.AUTHORIZE" then return sales~pay(detail["saleId"],detail["paymentMethodToken"])
    when action = "BOOKING.LOOKUP" then return operations~bookingLookup(detail["bookingRef"],detail["familyName"])
    when action = "BOOKING.ADD_CHECKED_BAG" then do
      passengerIds=detail["passengerIds"]
      quantity=detail["quantity"]+0
      amountMinor=4900 * quantity * passengerIds~items
      idem=detail["idempotencyKey"]~string
      token=detail["paymentMethodToken"]~string
      intent=.FlyLoPaymentIntent~new("SVC-" || idem,token,amountMinor,"GBP","PAYMENT:" || idem)
      auth=sales~payments~authorize(intent)
      if auth["status"] <> "AUTHORIZED" then raise syntax 88.900 array("FLYLO_ANCILLARY_PAYMENT_DECLINED")
      updated=operations~addCheckedBags(detail["bookingRef"],passengerIds,quantity,auth["authorizationId"],idem)
      captureIntent=.FlyLoPaymentCaptureIntent~new("SVC-CAP-" || idem,auth["authorizationId"],amountMinor,"GBP","CAPTURE:" || idem)
      capture=sales~payments~capture(captureIntent)
      if capture==.nil | capture["status"]<>"CAPTURED" then do
        updated["lastAncillaryFinancialStatus"]="RECOVERY_REQUIRED"
        return updated
      end
      updated["lastAncillaryFinancialStatus"]="CAPTURED"
      updated["lastAncillaryCaptureId"]=capture["captureId"]
      if accounting<>.nil then do
        posted=accounting~recordAncillaryCapture(updated["lastAncillaryService"],capture)
        if posted~ok then do
          updated["lastAncillaryAccountingStatus"]=posted~status
          updated["lastAncillaryAccountingEntryId"]=posted~entry~entryId
        end
        else do
          updated["lastAncillaryAccountingStatus"]="RECOVERY_REQUIRED"
          updated["lastAncillaryAccountingError"]=posted~errorCode
        end
      end
      return updated
    end
    when action = "FLIGHT.STATUS" then return operations~flightStatus(detail["flightNo"],detail["date"])
    otherwise raise syntax 88.900 array("FLYLO_ACTION_UNSUPPORTED", action)
  end

::method saleStatus
  expose sales
  use arg saleId
  return sales~status(saleId)

::requires "FlyLoSalesProcess.cls"
