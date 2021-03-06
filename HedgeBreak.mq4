//+------------------------------------------------------------------+
//|                                              HL_Monday_Order.mq4 |
//|                           Copyright 2017, Palawan Software, Ltd. |
//|                             https://coconala.com/services/204383 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Palawan Software, Ltd."
#property link      "https://coconala.com/services/204383"
#property description "Author: Kotaro Hashimoto <hasimoto.kotaro@gmail.com>"
#property version   "1.00"
#property strict

//--- input parameters
input int Magic_Number = 1;

input bool Flat_Lot = True;
input double Flat_Lot_Rate = 0.01;

input bool MM_Lot = False;
input double MM_Rate = 500000;
// entry lot = AccountEquity() / MM_Rate * 0.01

input int Min_Equity_For_Entry = 300000;
input int Equity_StopLoss = 200000;
input int Equity_TakeProfit = 1000000;

input bool EMA_Filter = True;
input int EMA_Period = 12;
input bool Buy_First = True;
// Sell First if Buy_First = False

input double Pips_Wide = 5.0;
input double Buy_Lot_Times = 1.2;
input double Sell_Lot_Times = 1.2;
input double Max_Lot = 2.0;
input double Exit_Pips = 5.0;
input bool Friday_PM_New_Entry_Stop = True;

input double Total_Stop_Pips = 2000;

input bool Entry_Times_Exit = False;
input int Entry_Times_Exit_Total_Priod = 10;
input int Entry_Times_Exit_Difference_Priod = 3;


string thisSymbol;

int sellOrderCount;
int buyOrderCount;

int positionCount;

double firstEntryPoint;
int sOffSet;
int lOffSet;

bool nowExiting;

double minLot;
double maxLot;
double lotSize;
double lotStep;


int determineFirstEntry() {

  if(!EMA_Filter) {
    if(Buy_First) {
      return OP_BUY;
    }
    else {
      return OP_SELL;
    }
  }
  else {
    double ema1 = iMA(thisSymbol, PERIOD_CURRENT, EMA_Period, 0, MODE_EMA, PRICE_WEIGHTED, 1);
    double ema2 = iMA(thisSymbol, PERIOD_CURRENT, EMA_Period, 0, MODE_EMA, PRICE_WEIGHTED, 2);

    if(ema2 < ema1) {
      return OP_BUY;
    }
    else if(ema2 > ema1) {
      return OP_SELL;
    }
    else {
      return -1;
    }
  }
}

bool nextNumpin(double numpinCount) {

  double lot = calcLot();
  if(lot == 0.0) {
    return False;
  }

  double buyLot = lot * MathPow(Buy_Lot_Times, numpinCount);
  buyLot = MathFloor(buyLot / lotStep) * lotStep;
  if(Max_Lot < buyLot) {
    buyLot = Max_Lot;
  }

  double sellLot = lot * MathPow(Sell_Lot_Times, numpinCount);
  sellLot = MathFloor(sellLot / lotStep) * lotStep;
  if(Max_Lot < sellLot) {
    sellLot = Max_Lot;
  }
  
  double nextBuyPrice = firstEntryPoint + ((numpinCount + double(lOffSet)) * 10.0 * Point * Pips_Wide);
  double nextSellPrice = firstEntryPoint - ((numpinCount + double(sOffSet)) * 10.0 * Point * Pips_Wide);
  double minSL = MarketInfo(thisSymbol, MODE_STOPLEVEL) * Point;

  if(Bid - nextSellPrice < minSL) {
    Print("Next sell stop order(", nextSellPrice, ") is too close to current price. minSL = ", minSL);
    return False;
  }
  else if(nextBuyPrice - Ask < minSL) {
    Print("Next buy stop order(", nextBuyPrice, ") is too close to current price. minSL = ", minSL);
    return False;
  }
  else {
  
    int ticket1 = OrderSend(thisSymbol, OP_SELLSTOP, sellLot, NormalizeDouble(nextSellPrice, Digits), 3, 0, 0, NULL, Magic_Number);
    int ticket2 = OrderSend(thisSymbol, OP_BUYSTOP, buyLot, NormalizeDouble(nextBuyPrice, Digits), 3, 0, 0, NULL, Magic_Number);
    
    if(ticket1 == -1 && ticket2 != -1) {
      while(!OrderDelete(ticket2)) {
        Sleep(1000);
      }
      return False;
    }
    else if(ticket1 != -1 && ticket2 == -1) {
      while(!OrderDelete(ticket1)) {
        Sleep(1000);
      }
      return False;
    }
    else if(ticket1 == -1 && ticket2 == -1) {
      return False;
    }

    return True;
  }
}

bool initialEntry() {

  positionCount = 0;

  double equity = AccountEquity();

  if(equity < Min_Equity_For_Entry) {
    Print("Account Equity is too low: " + DoubleToString(equity, 0) + " (< " + IntegerToString(Min_Equity_For_Entry) + ")");
    return False;
  }
  else if(Equity_TakeProfit < equity) {
    Print("Account Equity is too high: " + DoubleToString(equity, 0) + " (< " + IntegerToString(Equity_TakeProfit) + ")");
    return False;
  }
  else if(Friday_PM_New_Entry_Stop) {
    if(DayOfWeek() == 5 && 6 < Hour()) {
      return False;
    }
  }


  int firstDirection = determineFirstEntry();
  if(firstDirection == -1) {
    Print("Cannot determine entry direction.");
    return False;
  }

  double lot = calcLot();
  if(lot == 0.0) {
    return False;
  }

  double minSL = MarketInfo(thisSymbol, MODE_STOPLEVEL) * Point;
  double nextOrderPrice;

  if(firstDirection == OP_BUY) {
    nextOrderPrice = Ask - (10.0 * Point * Pips_Wide);

    if(Bid - nextOrderPrice < minSL) {
      Print("Next sell stop order(", nextOrderPrice, ") is too close to current price. minSL = ", minSL);

      return False;
    }
    else {
      int ticket1 = OrderSend(thisSymbol, OP_BUY, lot, NormalizeDouble(Ask, Digits), 3, 0, NormalizeDouble(Ask + (10.0 * Point * Pips_Wide), Digits), NULL, Magic_Number);
      int ticket2 = OrderSend(thisSymbol, OP_SELLSTOP, lot, NormalizeDouble(nextOrderPrice, Digits), 3, 0, 0, NULL, Magic_Number);

      if(ticket1 == -1 || ticket2 == -1) {
        nowExiting = !closeAll();
        return False;
      }

      firstEntryPoint = NormalizeDouble(Ask, Digits);
      sOffSet = 1;
      lOffSet = 0;

      return True;
    }
  }
  else { // OP_SELL
    nextOrderPrice = Bid + (10.0 * Point * Pips_Wide);

    if(nextOrderPrice - Ask < minSL) {
      Print("Next buy stop order(", nextOrderPrice, ") is too close to current price. minSL = ", minSL);
      return False;
    }
    else {
      int ticket1 = OrderSend(thisSymbol, OP_SELL, lot, NormalizeDouble(Bid, Digits), 3, 0, NormalizeDouble(Bid - (10.0 * Point * Pips_Wide), Digits), NULL, Magic_Number);
      int ticket2 = OrderSend(thisSymbol, OP_BUYSTOP, lot, NormalizeDouble(nextOrderPrice, Digits), 3, 0, 0, NULL, Magic_Number);

      if(ticket1 == -1 || ticket2 == -1) {
        nowExiting = !closeAll();
        return False;
      }

      firstEntryPoint = NormalizeDouble(Bid, Digits);
      sOffSet = 0;
      lOffSet = 1;

      return True;
    }
  }
}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  thisSymbol = Symbol();

  sellOrderCount = 0;
  buyOrderCount = 0;

  firstEntryPoint = 0.0;

  sOffSet = 0;
  lOffSet = 0;

  nowExiting = False;

  minLot = MarketInfo(Symbol(), MODE_MINLOT);
  maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
  lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
  lotSize = MarketInfo(Symbol(), MODE_LOTSIZE);
  
  //---
  return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  //---   
}

bool closeAll(bool pendingOnly = False) {

  int toClose = 0;
  int initialTotal = OrdersTotal();
  
  for(int i = 0; i < OrdersTotal(); i++) {      
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol) && OrderMagicNumber() == Magic_Number) {
      
        if(OrderType() == OP_BUY && !pendingOnly) {
          toClose ++;
          if(!OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Bid, Digits), 3)) {
            Print("Error on closing long order: ", GetLastError());
          }
          else {
            i = -1;
          }
        }
        else if(OrderType() == OP_SELL && !pendingOnly) {
          toClose ++;
          if(!OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Ask, Digits), 3)) {
            Print("Error on closing short order: ", GetLastError());
          }
          else {
            i = -1;
          }
        }
        else if(OrderType() == OP_BUYSTOP) {
          toClose ++;
          if(!OrderDelete(OrderTicket())) {
            Print("Error on deleting buy stop order: ", GetLastError());
          }
          else {
            i = -1;
          }
        }
        else if(OrderType() == OP_SELLSTOP) {
          toClose ++;
          if(!OrderDelete(OrderTicket())) {
            Print("Error on deleting sell stop order: ", GetLastError());
          }
          else {
            i = -1;
          }
        }
      }
    }
  }
  
  return (initialTotal - toClose == OrdersTotal());
}


bool validateParameters() {

  if(MM_Rate == 0.0) {
    Print("MM_Rate must be grater than zero.");
    return False;
  }

  return True;
}


void countOrders() {

  sellOrderCount = 0;
  buyOrderCount = 0;

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol) && OrderMagicNumber() == Magic_Number) {
        if(OrderType() == OP_SELL)
          sellOrderCount ++;
        else if(OrderType() == OP_BUY)
          buyOrderCount ++;
      }
    }
  }
}

void unlockTP() {

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol) && OrderMagicNumber() == Magic_Number) {
        if(OrderTakeProfit() != 0.0) {
          while(!OrderModify(OrderTicket(), OrderOpenPrice(), 0, 0, 0));
        }
      }
    }
  }
}




double calcLot() {

  double lot = 0.0;

  if(Flat_Lot) {
    lot = Flat_Lot_Rate;
  }
  else if(MM_Lot) {
    lot = AccountEquity() / MM_Rate * 0.01;
  }

  lot = MathRound(lot / lotStep) * lotStep;
  
  if(maxLot < lot) {
    lot = maxLot;
    Print("Lot size(", lot, ") is larger than max(", maxLot, "). Rounded to ", maxLot, ".");
  }
  else if(lot < minLot) {
    lot = 0.0;
    Print("Lot size(", lot, ") is smaller than min(", minLot, "). Entry skipped.");
  }
  
  return lot;
}

bool determineExit() {

  if(AccountEquity() < Equity_StopLoss) {
    return True;
  }
  
  int totalPips = countTotalPips();
  
  if(totalPips < -1 * Total_Stop_Pips) {
    return True;
  }

  else if(Entry_Times_Exit) {
    if(Entry_Times_Exit_Total_Priod - 1 < sellOrderCount + buyOrderCount) {
      if(Entry_Times_Exit_Difference_Priod - 1 < MathAbs(sellOrderCount - buyOrderCount)) {
        return True;
      }
    }
  }
  else if(Exit_Pips < totalPips) {
    return True;
  }

  return False;
}

int countTotalPips() {

  int totalPips = 0;

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol) && OrderMagicNumber() == Magic_Number) {
        if(OrderType() == OP_SELL) {
          totalPips += int((OrderOpenPrice() - Ask) / (Point * 10.0));
        }
        else if(OrderType() == OP_BUY) {
          totalPips += int((Bid - OrderOpenPrice()) / (Point * 10.0));
        }
      }
    }
  }

  return totalPips;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  if(!validateParameters()) {
    return;
  }

  countOrders();

  if(nowExiting || determineExit()) {
    nowExiting = !closeAll();
    Print("sell order count: ", sellOrderCount, " buy order count: ", buyOrderCount);
    return;
  }

  if(sellOrderCount == 0 && buyOrderCount == 0) {
    if(closeAll(True)) {
      initialEntry();
      return;
    }
  }
  else if(0 < sellOrderCount && 0 < buyOrderCount) {

    int numpinCount = (sellOrderCount + buyOrderCount) - 1;
    if(positionCount == 0 && numpinCount == 1) {
      positionCount = numpinCount;
      unlockTP();
      nextNumpin(double(numpinCount));
    }
    else if(positionCount < numpinCount) {
      positionCount = numpinCount;
      nextNumpin(double(numpinCount));
    }
  }
}

