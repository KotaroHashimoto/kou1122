//+------------------------------------------------------------------+
//|                                               HedgingTsunagi.mq4 |
//|                           Copyright 2017, Palawan Software, Ltd. |
//|                             https://coconala.com/services/204383 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Palawan Software, Ltd."
#property link      "https://coconala.com/services/204383"
#property description "Author: Kotaro Hashimoto <hasimoto.kotaro@gmail.com>"
#property version   "1.00"
#property strict

//--- input parameters
input int BUY_Magic_Number = 1111;
input int SELL_Magic_Number = 2222;


//-----------------------
//BASIC BUY SET
//-----------------------
input double Buy_Lot = 0.01;
input bool Buy_MM = False;
input double Buy_MM_per_001 = 100000;

input bool Buy_Entry = True;
input int Buy_Entry_Adjust_pips = 0;
input int Buy_TP = 200;
input int Buy_SL = 0;
input bool Buy_trailing_stop = True;
input int Buy_trailing_stop_width = 40;
input bool Buy_TP_trailing = True;
input bool Buy_hedging = True;


//-----------------------
//BASIC SELL SET
//-----------------------
input double Sell_Lot = 0.01;
input bool Sell_MM = False;
input double Sell_MM_per_001 = 100000;

input bool Sell_Entry = True;
input int Sell_Entry_Adjust_pips = 0;
input int Sell_TP = 200;
input int Sell_SL = 0;
input bool Sell_trailing_stop = True;
input int Sell_trailing_stop_width = 40;
input bool Sell_TP_trailing = True;
input bool Sell_hedging = True;


//-----------------------
//HEADING SET
//-----------------------
input int Hedging_Start_pips = 20;
input int Hedging_Keep_pips = 80;
input int Hedging_TP = 20;


//-----------------------
//OTHER
//-----------------------
input bool EA_Repeat = True;


enum SET {
  BUY = True,
  SELL = False,
};


string thisSymbol;

int sOrderCount;
int lOrderCount;
int sLiveCount;
int lLiveCount;

double sTotalPips;
double lTotalPips;

int lBottom;
int lTop;
int sBottom;
int sTop;

double minLot;
double maxLot;
double lotSize;
double lotStep;
double minSL;

void scanTickets() {

  lBottom = -1;
  lTop = -1;
  sBottom = -1;
  sTop = -1;
  
  double lMin = 100000;
  double sMin = 100000;
  double lMax = 0;
  double sMax = 0;

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol)) {
        if(OrderMagicNumber() == BUY_Magic_Number) {
          if(OrderOpenPrice() < lMin) {
            lMin = OrderOpenPrice();
            lBottom = OrderTicket();
          }
          if(lMax < OrderOpenPrice()) {
            lMax = OrderOpenPrice();
            lTop = OrderTicket();
          }
        }
        else if(OrderMagicNumber() == SELL_Magic_Number) {
          if(OrderOpenPrice() < sMin) {
            sMin = OrderOpenPrice();
            sBottom = OrderTicket();
          }
          if(sMax < OrderOpenPrice()) {
            sMax = OrderOpenPrice();
            sTop = OrderTicket();
          }
        }
      }
    }
  }
}

int getMagicNumber(SET d) {
  if(d == BUY) {
    return BUY_Magic_Number;
  }
  else {
    return SELL_Magic_Number;
  }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  thisSymbol = Symbol();

  sOrderCount = 0;
  lOrderCount = 0;

  minLot = MarketInfo(Symbol(), MODE_MINLOT);
  maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
  lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
  lotSize = MarketInfo(Symbol(), MODE_LOTSIZE);
  minSL = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
  
  initialEntry();
  
  //---
  return(INIT_SUCCEEDED);
}

double trailTP(bool yes, SET d) {

  if(!yes) {
    return OrderTakeProfit();
  }
  
  if(d == BUY) {
    return NormalizeDouble(Ask + Buy_TP * Point * 10.0, Digits);
  }
  else if(d == SELL){
    return NormalizeDouble(Bid - Sell_TP * Point * 10.0, Digits);
  }
  
  return 0.0;
}

double initialSL(double price, SET d) {

  if(d == BUY) {
    if(Buy_hedging) {
      return 0;
    }
    else if(Buy_SL == 0){
      return 0;
    }
    else {
      return NormalizeDouble(price - Buy_SL * Point * 10.0, Digits);
    }
  }
  else if(d == SELL) {
    if(Sell_hedging) {
      return 0;
    }
    else if(Sell_SL == 0){
      return 0;
    }
    else {
      return NormalizeDouble(price + Sell_SL * Point * 10.0, Digits);
    }
  }

  return 0;
}


double initialTP(double price, SET d) {

  if(d == BUY) {
    if(Buy_TP == 0){
      return 0;
    }
    else {
      return NormalizeDouble(price + Buy_TP * Point * 10.0, Digits);
    }
  }
  else if(d == SELL) {
    if(Sell_SL == 0){
      return 0;
    }
    else {
      return NormalizeDouble(price - Sell_TP * Point * 10.0, Digits);
    }
  }

  return 0;
}


void initialEntry() {

  if(Buy_Entry) {
    if(Buy_Entry_Adjust_pips == 0) {
      int t = OrderSend(Symbol(), OP_BUY, calcLot(BUY), NormalizeDouble(Ask, Digits), 3, initialSL(Ask, BUY), initialTP(Ask, BUY), NULL, BUY_Magic_Number);
    }
    if(Buy_Entry_Adjust_pips < 0) {
      double price = Ask + (Buy_Entry_Adjust_pips * Point * 10.0);
      int t = OrderSend(Symbol(), OP_BUYLIMIT, calcLot(BUY), NormalizeDouble(price, Digits), 3, initialSL(price, BUY), initialTP(price, BUY), NULL, BUY_Magic_Number);
    }
    if(0 < Buy_Entry_Adjust_pips) {
      double price = Ask + (Buy_Entry_Adjust_pips * Point * 10.0);
      int t = OrderSend(Symbol(), OP_BUYSTOP, calcLot(BUY), NormalizeDouble(price, Digits), 3, initialSL(price, BUY), initialTP(price, BUY), NULL, BUY_Magic_Number);
    }
  }

  if(Sell_Entry) {
    if(Sell_Entry_Adjust_pips == 0) {
      int t = OrderSend(Symbol(), OP_SELL, calcLot(SELL), NormalizeDouble(Bid, Digits), 3, initialSL(Bid, SELL), initialTP(Bid, SELL), NULL, SELL_Magic_Number);
    }
    if(Buy_Entry_Adjust_pips < 0) {
      double price = Bid - (Buy_Entry_Adjust_pips * Point * 10.0);
      int t = OrderSend(Symbol(), OP_SELLLIMIT, calcLot(SELL), NormalizeDouble(price, Digits), 3, initialSL(price, SELL), initialTP(price, SELL), NULL, SELL_Magic_Number);
    }
    if(0 < Buy_Entry_Adjust_pips) {
      double price = Ask - (Buy_Entry_Adjust_pips * Point * 10.0);
      int t = OrderSend(Symbol(), OP_SELLSTOP, calcLot(SELL), NormalizeDouble(price, Digits), 3, initialSL(price, SELL), initialTP(price, SELL), NULL, SELL_Magic_Number);
    }
  }
}

void trail() {

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol)) {
        if(OrderMagicNumber() == BUY_Magic_Number && OrderType() == OP_BUY) {
          if(lLiveCount == 1 && Buy_trailing_stop) {
            if(OrderStopLoss() == 0.0 || OrderStopLoss() + Buy_trailing_stop_width * 10.0 * Point < Ask) {
              bool mod = OrderModify(OrderTicket(), OrderOpenPrice(), NormalizeDouble(Ask - Buy_trailing_stop_width * 10.0 * Point, Digits), trailTP(Buy_TP_trailing, BUY), 0);
            }
          }
          if(1 < lLiveCount && 0 < OrderStopLoss() && 0 < OrderTakeProfit()) {
            bool mod = OrderModify(OrderTicket(), OrderOpenPrice(), 0, 0, 0);
          }
          if(0 == lLiveCount && 1 == lOrderCount && OrderType() == OP_SELLSTOP) {
            bool del = OrderDelete(OrderTicket());
          }
        }
        else if(OrderMagicNumber() == SELL_Magic_Number && OrderType() == OP_SELL) {
          if(sLiveCount == 1 && Sell_trailing_stop) {
            if(OrderStopLoss() == 0.0 || Bid < OrderStopLoss() - Sell_trailing_stop_width * 10.0 * Point) {
              bool mod = OrderModify(OrderTicket(), OrderOpenPrice(), NormalizeDouble(Bid + Sell_trailing_stop_width * 10.0 * Point, Digits), trailTP(Sell_TP_trailing, SELL), 0);
            }
          }
          if(1 < sLiveCount && 0 < OrderStopLoss() && 0 < OrderTakeProfit()) {
            bool mod = OrderModify(OrderTicket(), OrderOpenPrice(), 0, 0, 0);
          }
          if(0 == sLiveCount && 1 == sOrderCount && OrderType() == OP_BUYSTOP) {
            bool del = OrderDelete(OrderTicket());
          }
        }
      }
    }
  }
}


//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  //---   
}

void closeAll(SET d) {

  int magicNumber = getMagicNumber(d);

  for(int i = 0; i < OrdersTotal(); i++) {      
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol) && OrderMagicNumber() == magicNumber) {
      
        if(OrderType() == OP_BUY) {
          if(!OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Bid, Digits), 3)) {
            Print("Error on closing long order: ", GetLastError());
          }
          else {
            i = -1;
          }
        }
        else if(OrderType() == OP_SELL) {
          if(!OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Ask, Digits), 3)) {
            Print("Error on closing short order: ", GetLastError());
          }
          else {
            i = -1;
          }
        }
        else if(OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP) {
          if(!OrderDelete(OrderTicket())) {
            Print("Error on deleting buy stop order: ", GetLastError());
          }
          else {
            i = -1;
          }
        }
      }
    }
  }
}


void HedgeEntry() {

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol)) {
        if(OrderMagicNumber() == BUY_Magic_Number && OrderType() == OP_BUY && Buy_hedging) {
          if(lLiveCount == 1 && lOrderCount == 1) {
            int t = OrderSend(Symbol(), OP_SELLSTOP, calcLot(BUY), NormalizeDouble(OrderOpenPrice() - Hedging_Start_pips * Point * 10.0, Digits), 3, 0, 0, NULL, BUY_Magic_Number);
          }
        }
        else if(OrderMagicNumber() == SELL_Magic_Number && OrderType() == OP_SELL && Sell_hedging) {
          if(sLiveCount == 1 && sOrderCount == 1) {
            int t = OrderSend(Symbol(), OP_BUYSTOP, calcLot(SELL), NormalizeDouble(OrderOpenPrice() + Hedging_Start_pips * Point * 10.0, Digits), 3, 0, 0, NULL, SELL_Magic_Number);
          }
        }
      }
    }
  }
}

void countOrders() {

  sOrderCount = 0;
  lOrderCount = 0;
  sLiveCount = 0;
  lLiveCount = 0;

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol)) {
        if(OrderMagicNumber() == BUY_Magic_Number) {
          lOrderCount ++;
          if(OrderType() == OP_BUY || OrderType() == OP_SELL) {
            lLiveCount ++;
          }
        }
        else if(OrderMagicNumber() == SELL_Magic_Number) {
          sOrderCount ++;
          if(OrderType() == OP_SELL || OrderType() == OP_BUY) {
            sLiveCount ++;
          }
        }
      }
    }
  }
}

double calcLot(SET d) {

  double lot = 0.0;

  if(d == BUY) {
    if(!Buy_MM) {
      lot = Buy_Lot;
    }
    else {
      lot = AccountEquity() / Buy_MM_per_001 * 0.01;
    }
  }
  else {
    if(!Sell_MM) {
      lot = Sell_Lot;
    }
    else {
      lot = AccountEquity() / Sell_MM_per_001 * 0.01;
    }
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


void countTotalPips() {

  sTotalPips = 0.0;
  lTotalPips = 0.0;

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol)) {
        if(OrderMagicNumber() == BUY_Magic_Number) {
          if(OrderType() == OP_SELL) {
            lTotalPips += (OrderOpenPrice() - Ask) / (Point * 10.0);
          }
          else if(OrderType() == OP_BUY) {
            lTotalPips += (Bid - OrderOpenPrice()) / (Point * 10.0);
          }
        }
        else if(OrderMagicNumber() == SELL_Magic_Number) {
          if(OrderType() == OP_SELL) {
            sTotalPips += (OrderOpenPrice() - Ask) / (Point * 10.0);
          }
          else if(OrderType() == OP_BUY) {
            sTotalPips += (Bid - OrderOpenPrice()) / (Point * 10.0);
          }
        }
      }
    }
  }
}


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{

  countOrders();

  if(sOrderCount == 0 && lOrderCount == 0 && EA_Repeat) {
    initialEntry();
    return;
  }

  HedgeEntry();
  trail();

  countTotalPips();
  if(Hedging_TP < lTotalPips) {
    closeAll(BUY);
    return;
  }
  if(Hedging_TP < sTotalPips) {
    closeAll(SELL);
    return;
  }

  scanTickets();
  if(1 < lLiveCount) {
    if(OrderSelect(lBottom, SELECT_BY_TICKET)) {
      if(Ask + Hedging_Keep_pips * Point * 10.0 < OrderOpenPrice() && OrderType() == OP_SELL) {
        int t0 = OrderSend(Symbol(), OP_BUY, calcLot(BUY), Ask, 3, 0, 0, NULL, BUY_Magic_Number);
        int t1 = OrderSend(Symbol(), OP_SELLSTOP, calcLot(BUY), Ask - Hedging_Start_pips * Point * 10.0, 3, 0, 0, NULL, BUY_Magic_Number);
      }
    }
    if(OrderSelect(lTop, SELECT_BY_TICKET)) {
      if(OrderOpenPrice() + Hedging_Keep_pips * Point * 10.0 < Ask && OrderType() == OP_BUY) {
        int t0 = OrderSend(Symbol(), OP_SELL, calcLot(BUY), Bid, 3, 0, 0, NULL, BUY_Magic_Number);
        int t1 = OrderSend(Symbol(), OP_BUYSTOP, calcLot(BUY), Bid + Hedging_Start_pips * Point * 10.0, 3, 0, 0, NULL, BUY_Magic_Number);
      }
    }
  }
  if(1 < sLiveCount) {
    if(OrderSelect(sTop, SELECT_BY_TICKET)) {
      if(OrderOpenPrice() + Hedging_Keep_pips * Point * 10.0 < Bid && OrderType() == OP_BUY) {
        int t0 = OrderSend(Symbol(), OP_SELL, calcLot(SELL), Bid, 3, 0, 0, NULL, SELL_Magic_Number);
        int t1 = OrderSend(Symbol(), OP_BUYSTOP, calcLot(SELL), Bid + Hedging_Start_pips * Point * 10.0, 3, 0, 0, NULL, SELL_Magic_Number);
      }
    }
    if(OrderSelect(sBottom, SELECT_BY_TICKET)) {
      if(Bid + Hedging_Keep_pips * Point * 10.0 < OrderOpenPrice() && OrderType() == OP_SELL) {
        int t0 = OrderSend(Symbol(), OP_BUY, calcLot(SELL), Ask, 3, 0, 0, NULL, SELL_Magic_Number);
        int t1 = OrderSend(Symbol(), OP_SELLSTOP, calcLot(SELL), Ask - Hedging_Start_pips * Point * 10.0, 3, 0, 0, NULL, SELL_Magic_Number);
      }
    }
  }
}
