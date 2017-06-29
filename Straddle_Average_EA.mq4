//+------------------------------------------------------------------+
//|                                          Straddle_Average_EA.mq4 |
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

input bool MM_Lot = True;
input double MM_Rate = 100000;
// entry lot = AccountEquity() / MM_Rate * 0.01

input bool Time_Entry = True;
input int Entry_JST_Time_1 = 9;
input int Entry_JST_Time_2 = 17;

input bool Monday_AM_No_Entry = False;
input bool Friday_PM_No_Entry = False;

input bool RSI_Range_Entey = True;
input int RSI_Period = 9;
input double RSI_Min_Level = 40;
input double RSI_Max_Level = 60;

input bool Entry_Time = True;
input int Entry_Time_JST_Start_Hour = 7;
input int Entry_Time_JST_End_Hour = 21;
input bool RSI_Monday_AM_No_Entry = False;
input bool RSI_Friday_PM_No_Entry = False;

input bool Saturday_Intend_To_All_Exit = True;
input int Saturday_Time_Adjust_Hour = 2;


input double Range_Wide_Pips = 20;
input double TP = 20;
input double SL = 40;
input int Max_Level = 10;
input double ALL_SL_Interval_Hour = 2;

input double Level_2_Lot_Times = 1.0;
input double Level_3_Lot_Times = 3.5;
input double Level_4_Lot_Times = 6.0;
input double Level_5_Lot_Times = 15.0;
input double Level_6_Lot_Times = 30.0;
input double Level_7_Lot_Times = 68.0;
input double Level_8_Lot_Times = 145.0;
input double Level_9_Lot_Times = 320.0;
input double Level_10_Lot_Times = 688.0;
input double Level_11_Lot_Times = 1498.0;


string thisSymbol;

int sellOrderCount;
int buyOrderCount;
int limitOrderCount;

double minLot;
double maxLot;
double lotSize;
double lotStep;

double initialLot;
double stopLoss;
double takeProfit;
double nampinSpan;

int lowestBuy;
int highestBuy;
int lowestSell;
int highestSell;

int nampinCount;
double lastLargestLoss;

datetime lastLossTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  thisSymbol = Symbol();

  countOrders();
  
  stopLoss = SL * Point * 10;
  takeProfit = TP * Point * 10;
  nampinSpan = Range_Wide_Pips * Point * 10;
  nampinCount = 0;
  
  lastLossTime = (datetime)0;

  minLot = MarketInfo(Symbol(), MODE_MINLOT);
  maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
  lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
  lotSize = MarketInfo(Symbol(), MODE_LOTSIZE);
  
  //---
  return(INIT_SUCCEEDED);
}


bool initialEntryCondition() {

  if(0 < sellOrderCount || 0 < buyOrderCount) {
    return False;
  }
  
  if(TimeLocal() - lastLossTime < ALL_SL_Interval_Hour * 3600.0) {
    return False;
  }

  int h = TimeHour(TimeLocal());
  int m = TimeMinute(TimeLocal());
  int dow = TimeDayOfWeek(TimeLocal());
  
  if(Time_Entry) {
    if(dow % 6 == 0 || (dow == 1 && h < 12) || (dow == 5 && 12 <= h)) {
      return False;
    }
    
    if(m == 0) {
      if(h == Entry_JST_Time_1) {
        return True;
      }
      if(h == Entry_JST_Time_2 && Entry_JST_Time_2 != 0) {
        return True;
      }
    }
  }
  else if(RSI_Range_Entey) {
    if(Entry_Time) {
      if(dow % 6 == 0 || (RSI_Monday_AM_No_Entry && dow == 1 && h < 12) || (RSI_Friday_PM_No_Entry && dow == 5 && 12 <= h)) {
        return False;
      }
      if(Entry_Time_JST_Start_Hour < Entry_Time_JST_End_Hour) {
        if(h < Entry_Time_JST_Start_Hour || Entry_Time_JST_End_Hour <= h) {
          return False;
        }
      }
      else {
        if(Entry_Time_JST_End_Hour <= h && h < Entry_Time_JST_Start_Hour) {
          return False;
        }
      }
    }
    
    double rsi = iRSI(thisSymbol, PERIOD_CURRENT, RSI_Period, PRICE_WEIGHTED, 0);
    if(RSI_Min_Level < rsi && rsi < RSI_Max_Level) {
      return True;
    }
  }
  else {
    return True;
  }
  
  return False;
}


//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{

  //---   
}

void closeAll(bool pendingOnly = False) {

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol) && OrderMagicNumber() == Magic_Number) {
        if(OrderType() == OP_BUY && !pendingOnly) {
          if(!OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(MarketInfo(thisSymbol, MODE_BID), Digits), 0)) {
            Print("Error on closing long order: ", GetLastError());
          }
          else {
            i = -1;
          }
        }
        else if(OrderType() == OP_SELL && !pendingOnly) {
          if(!OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(MarketInfo(thisSymbol, MODE_ASK), Digits), 3)) {
            Print("Error on closing short order: ", GetLastError());
          }
          else {
            i = -1;
          }
        }
        else if(OrderType() == OP_BUYLIMIT) {
          if(!OrderDelete(OrderTicket())) {
            Print("Error on deleting buy stop order: ", GetLastError());
          }
          else {
            i = -1;
          }
        }
        else if(OrderType() == OP_SELLLIMIT) {
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
  
  return;
}


void countOrders() {

  sellOrderCount = 0;
  buyOrderCount = 0;
  limitOrderCount = 0;
  
  highestBuy = -1;
  highestSell = -1;
  lowestBuy = -1;
  lowestSell = -1;
  
  if(0 < OrdersTotal()) {
    lastLargestLoss = 1000000;
  }

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol) && OrderMagicNumber() == Magic_Number) {
        if(OrderType() == OP_SELL) {
          sellOrderCount ++;
          
          if(OrderProfit() < lastLargestLoss) {
            lastLargestLoss = OrderProfit();
          }
          
          if(highestSell == -1) {
            highestSell = OrderTicket();
          }
          if(lowestSell == -1) {
            lowestSell = OrderTicket();
          }          
          
          double openPrice = OrderOpenPrice();
          int ticket = OrderTicket();
          if(OrderSelect(highestSell, SELECT_BY_TICKET)) {
            if(OrderOpenPrice() < openPrice) {
              highestSell = ticket;
            }
          }
          if(OrderSelect(lowestSell, SELECT_BY_TICKET)) {
            if(openPrice < OrderOpenPrice()) {
              lowestSell = ticket;
            }
          }          
        }
        else if(OrderType() == OP_SELLLIMIT) {
          sellOrderCount ++;
          limitOrderCount ++;
        }
        
        else if(OrderType() == OP_BUY) {
          buyOrderCount ++;
          
          if(OrderProfit() < lastLargestLoss) {
            lastLargestLoss = OrderProfit();
          }

          if(highestBuy == -1) {
            highestBuy = OrderTicket();
          }
          if(lowestBuy == -1) {
            lowestBuy = OrderTicket();
          }
          
          double openPrice = OrderOpenPrice();
          int ticket = OrderTicket();
          if(OrderSelect(highestBuy, SELECT_BY_TICKET)) {
            if(OrderOpenPrice() < openPrice) {
              highestBuy = ticket;
            }
          }
          if(OrderSelect(lowestBuy, SELECT_BY_TICKET)) {
            if(openPrice < OrderOpenPrice()) {
              lowestBuy = ticket;
            }
          }          
        }
        else if(OrderType() == OP_BUYLIMIT) {
          buyOrderCount ++;
          limitOrderCount ++;
        }        
      }
    }
  }
}

double calcLot(double given = -1.0) {

  double lot = given;

  if(lot < 0.0) {
    if(Flat_Lot) {
      lot = Flat_Lot_Rate;
    }
    else if(MM_Lot) {
      lot = AccountEquity() / MM_Rate * lotStep;
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


void initialEntry() {

  initialLot = calcLot();

  if(0.0 < initialLot) {
    int ticket0 = OrderSend(thisSymbol, OP_BUY, initialLot, NormalizeDouble(Ask, Digits), 0, NormalizeDouble(Ask - stopLoss, Digits), NormalizeDouble(Ask + takeProfit, Digits), NULL, Magic_Number);
    int ticket1 = OrderSend(thisSymbol, OP_SELL, initialLot, NormalizeDouble(Bid, Digits), 0, NormalizeDouble(Bid + stopLoss, Digits), NormalizeDouble(Bid - takeProfit, Digits), NULL, Magic_Number);

    if(0 < ticket0 && 0 < ticket1) {
      double nextLot = calcLot(initialLot * Level_2_Lot_Times);
      int ticket2 = OrderSend(thisSymbol, OP_BUYLIMIT, nextLot, NormalizeDouble(Ask - nampinSpan, Digits), 0, NormalizeDouble(Ask - nampinSpan - stopLoss, Digits), NormalizeDouble(Ask - nampinSpan + takeProfit, Digits), NULL, Magic_Number);
      int ticket3 = OrderSend(thisSymbol, OP_SELLLIMIT, nextLot, NormalizeDouble(Bid + nampinSpan, Digits), 0, NormalizeDouble(Bid + nampinSpan + stopLoss, Digits), NormalizeDouble(Bid + nampinSpan - takeProfit, Digits), NULL, Magic_Number);

      if(0 < ticket2 && 0 < ticket3) {
        nampinCount = 2;
      }
    }
  }
}

double nextLot() {

  double nextTimes = 0.0;
  
  switch(nampinCount) {
    case 2:
      nextTimes = Level_3_Lot_Times;
      break;
    case 3:
      nextTimes = Level_4_Lot_Times;
      break;
    case 4:
      nextTimes = Level_5_Lot_Times;
      break;
    case 5:
      nextTimes = Level_6_Lot_Times;
      break;
    case 6:
      nextTimes = Level_7_Lot_Times;
      break;
    case 7:
      nextTimes = Level_8_Lot_Times;
      break;
    case 8:
      nextTimes = Level_9_Lot_Times;
      break;
    case 9:
      nextTimes = Level_10_Lot_Times;
      break;
    case 10:
      nextTimes = Level_11_Lot_Times;
      break;
    case 11:
      nextTimes = 0;
      break;
    default:
      nextTimes = 0;
  }
  
  if(Max_Level == nampinCount) {
    return 0.0;
  }
  else {
    nampinCount ++;
    return calcLot(initialLot * nextTimes);
  }
}


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  if(TimeDayOfWeek(TimeLocal()) == 6 && Saturday_Intend_To_All_Exit) {
    datetime tm = TimeLocal();
    if((5 - Saturday_Time_Adjust_Hour) < TimeHour(tm) || (TimeMinute(tm) == 59 && TimeHour(tm) == (5 - Saturday_Time_Adjust_Hour))) {
      closeAll();
      return;
    }
  }
  
  countOrders();
  if(initialEntryCondition()) {
    initialEntry();
  }
  
  if((1 == limitOrderCount && sellOrderCount + buyOrderCount == 4)
  || (0 < limitOrderCount && limitOrderCount == sellOrderCount + buyOrderCount)) {
    closeAll(True);
    
    if(nampinCount == Max_Level && lastLargestLoss < 0.0) {
      lastLossTime = TimeLocal();
    }
    
    return;
  }
  
  if(limitOrderCount == 0) {
    if(buyOrderCount == 2 && sellOrderCount == 0) {
      double tp = -1.0;
      if(OrderSelect(lowestBuy, SELECT_BY_TICKET)) {
        tp = OrderTakeProfit();
        
        double lot = nextLot();
        if(0.0 < lot) {
          int ticket = OrderSend(thisSymbol, OP_BUYLIMIT, lot, NormalizeDouble(OrderOpenPrice() - nampinSpan, Digits), 0, NormalizeDouble(OrderOpenPrice() - nampinSpan - stopLoss, Digits), NormalizeDouble(OrderOpenPrice() - nampinSpan + takeProfit, Digits), NULL, Magic_Number);
        }
      }
      if(OrderSelect(highestBuy, SELECT_BY_TICKET)) {
        if(tp != OrderTakeProfit()) {
          bool mod = OrderModify(highestBuy, OrderOpenPrice(), OrderStopLoss(), tp, 0);
        }
      }      
    }

    if(sellOrderCount == 2 && buyOrderCount == 0) {
      double tp = -1.0;
      if(OrderSelect(highestSell, SELECT_BY_TICKET)) {
        tp = OrderTakeProfit();
        
        double lot = nextLot();
        if(0.0 < lot) {
          int ticket = OrderSend(thisSymbol, OP_SELLLIMIT, lot, NormalizeDouble(OrderOpenPrice() + nampinSpan, Digits), 0, NormalizeDouble(OrderOpenPrice() + nampinSpan + stopLoss, Digits), NormalizeDouble(OrderOpenPrice() + nampinSpan - takeProfit, Digits), NULL, Magic_Number);
        }
      }
      if(OrderSelect(lowestSell, SELECT_BY_TICKET)) {
        if(tp != OrderTakeProfit()) {
          bool mod = OrderModify(lowestSell, OrderOpenPrice(), OrderStopLoss(), tp, 0);
        }
      }
    }
  }
}
