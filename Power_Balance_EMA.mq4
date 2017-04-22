//+------------------------------------------------------------------+
//|                                            Power_Balance_EMA.mq4 |
//|                           Copyright 2017, Palawan Software, Ltd. |
//|                             https://coconala.com/services/204383 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Palawan Software, Ltd."
#property link      "https://coconala.com/services/204383"
#property description "Author: Kotaro Hashimoto <hasimoto.kotaro@gmail.com>"
#property version   "1.00"
#property strict

input int Magic_Number = 170411;

input bool Friday_PM_Entry = False;

input bool Flat_Lot = True;
input double Flat_Lot_Rate = 0.01;

input bool MM_Lot = False;
input double MM_Rate = 100000;
// entry lot = AccountEquity() / MM_Rate * 0.01

input int Min_Equity_For_Entry = 300000;
input int Equity_StopLoss = 200000;
input int Equity_TakeProfit = 1000000;

input bool PB_setting = True;
input int PB_distance = 2;
input bool GBP = True;
input bool EUR = True;
input bool CHF = False;
input bool AUD = True;
input bool USD = True;
input bool JPY = True;

enum Size {
  M1 = PERIOD_M1,
  M5 = PERIOD_M5,
  M15 = PERIOD_M15,
  M30 = PERIOD_M30,
  H1 = PERIOD_H1,
  H4 = PERIOD_H4,
  D1 = PERIOD_D1,
  W1 = PERIOD_W1,
  MN1 = PERIOD_MN1
};

input Size EMA_Time_Frame = M15;
input int EMA_Close_S_Period = 5;
input int EMA_Close_M_Period = 13;
input int EMA_Close_L_Period = 21;

input int TP = 100;
input int SL = 20;
input bool EMA_Exit = True;


string possiblePairs[] = {"USDJPY", "EURJPY", "GBPJPY", "AUDJPY", "EURUSD", 
                          "GBPUSD", "AUDCHF", "EURCHF", "GBPCHF", "USDCHF",
                          "CHFJPY", "EURAUD", "EURGBP", "GBPAUD", "AUDUSD"};

int signals[15];
int hasPositions[15];

int iGBP;
int iEUR;
int iCHF;
int iAUD;
int iUSD;
int iJPY;

int iMAX;
string symbols4H[6];
string symbols1D[6];

const string status4H = "status4H";
const string status1D = "status1D";

const string standby[] = {"standby0", "standby1", "standby2", "standby3", "standby4"};

double minLot;
double maxLot;
double lotSize;
double lotStep;


double calcLot() {

  double lot = 0.0;

  if(MM_Lot) {
    lot = AccountEquity() / MM_Rate * lotStep;
  }
  else if(Flat_Lot) {
    lot = Flat_Lot_Rate;
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


void symbolSignal() {

  string lbl[] = {"Stand By:", "             ", "             ", "             ", "             "};
  double idx = -0.1;
  
  for(int i = 0; i < 15; i++) {
  
    signals[i] = -1;

    int d0 = getIndex(StringSubstr(possiblePairs[i], 0, 3), True);
    int d3 = getIndex(StringSubstr(possiblePairs[i], 3, 3), True);
    if(d0 == -1 || d3 == -1) {
      continue;
    }

    int h0 = getIndex(StringSubstr(possiblePairs[i], 0, 3), False);
    int h3 = getIndex(StringSubstr(possiblePairs[i], 3, 3), False);
    
    double maL1 = iMA(possiblePairs[i], EMA_Time_Frame, EMA_Close_L_Period, 0, MODE_EMA, PRICE_WEIGHTED, 1);
    double maL2 = iMA(possiblePairs[i], EMA_Time_Frame, EMA_Close_L_Period, 0, MODE_EMA, PRICE_WEIGHTED, 2);
    double maM1 = iMA(possiblePairs[i], EMA_Time_Frame, EMA_Close_M_Period, 0, MODE_EMA, PRICE_WEIGHTED, 1);
    double maM2 = iMA(possiblePairs[i], EMA_Time_Frame, EMA_Close_M_Period, 0, MODE_EMA, PRICE_WEIGHTED, 2);
    double maS1 = iMA(possiblePairs[i], EMA_Time_Frame, EMA_Close_S_Period, 0, MODE_EMA, PRICE_WEIGHTED, 1);
    double maS2 = iMA(possiblePairs[i], EMA_Time_Frame, EMA_Close_S_Period, 0, MODE_EMA, PRICE_WEIGHTED, 2);
    
    if(PB_distance < d0 - d3) {
      if(PB_distance < h0 - h3) {
        idx += 1.0;
        lbl[int(MathFloor(idx / 3.0))] += ", sell " + possiblePairs[i];

        if(maL2 < maS2 && maM2 < maS2 && maL1 > maS1 && maM1 > maS1) {
          signals[i] = OP_SELL;
        }
      }
    }
    if(PB_distance < d3 - d0) {
      if(PB_distance < h3 - h0) {
        idx += 1.0;
        lbl[int(MathFloor(idx / 3.0))] += ", buy " + possiblePairs[i];

        if(maL2 > maS2 && maM2 > maS2 && maL1 < maS1 && maM1 < maS1) {
          signals[i] = OP_BUY;
        }
      }
    }
  }
  
  for(int i = 0; i < 5; i++)
    ObjectSetText(standby[i], lbl[i], 10, "Arial", clrCyan);
}

void drawLabel() {

  ObjectCreate(0, status4H, OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, status4H, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSet(status4H, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
  ObjectSetInteger(0, status4H, OBJPROP_SELECTABLE, false);

  string lbl = "1D: ";
  ObjectSetText(status4H, lbl, 8, "Arial", clrYellow);

  ObjectCreate(0, status1D, OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, status1D, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSet(status1D, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
  ObjectSetInteger(0, status1D, OBJPROP_SELECTABLE, false);
  ObjectSetInteger(0, status1D, OBJPROP_YDISTANCE, 30);

  lbl = "4H: ";
  ObjectSetText(status1D, lbl, 8, "Arial", clrYellow);

  for(int i = 0; i < 5; i++) {
    ObjectCreate(0, standby[i], OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, standby[i], OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSet(standby[i], OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    ObjectSetInteger(0, standby[i], OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, standby[i], OBJPROP_YDISTANCE, 70 + i * 20);
    ObjectSetText(status1D, "", 8, "Arial", clrYellow);
  }
}

bool compareSymbol(string a, string b, int period) {

  bool dir = True;
  string s = "";
  int i;
  for(i = 0; i < 15; i++) {
    if(!StringCompare(possiblePairs[i], a + b)) {
      s = a + b;
      dir = True;
      break;
    }
    else if(!StringCompare(possiblePairs[i], b + a)) {
      s = b + a;
      dir = False;
      break;
    }    
  }
  if(i == 15) {
    return False;
  }
  
  if(iOpen(s, period, 0) < MarketInfo(s, MODE_BID)) {
    if(dir) {
      return True;
    }
    else {
      return False;
    }    
  }
  else {
    if(!dir) {
      return True;
    }
    else {
      return False;
    }
  }
}


void assignIndex() {

  int i = 0;
  if(GBP) {
    iGBP = i;
    symbols4H[i] = "GBP";
    symbols1D[i] = "GBP";
    i ++;
  }
  if(EUR) {
    iEUR = i;
    symbols4H[i] = "EUR";
    symbols1D[i] = "EUR";
    i ++;
  }
  if(CHF) {
    iCHF = i;
    symbols4H[i] = "CHF";
    symbols1D[i] = "CHF";
    i ++;
  }
  if(AUD) {
    iAUD = i;
    symbols4H[i] = "AUD";
    symbols1D[i] = "AUD";
    i ++;
  }
  if(JPY) {
    iUSD = i;
    symbols4H[i] = "USD";
    symbols1D[i] = "USD";
    i ++;
  }
  if(USD) {
    iJPY = i;
    symbols4H[i] = "JPY";
    symbols1D[i] = "JPY";
    i ++;
  }
  iMAX = i;  
}

void sortSymbols() {

  for(int i = 0; i < iMAX; i++) {
    for(int j = 0; j < iMAX; j++) {
      if(compareSymbol(symbols4H[i], symbols4H[j], PERIOD_H4)) {
        string tmp = symbols4H[i];
        symbols4H[i] = symbols4H[j];
        symbols4H[j] = tmp;
      }

      if(compareSymbol(symbols1D[i], symbols1D[j], PERIOD_D1)) {
        string tmp = symbols1D[i];
        symbols1D[i] = symbols1D[j];
        symbols1D[j] = tmp;
      }
    }
  }
}



int getIndex(string s, bool day) {

  if(day) {
    for(int i = 0; i < iMAX; i++) {
      if(!StringCompare(symbols1D[i], s)) {
        return i;
      }
    }
  }
  else {
    for(int i = 0; i < iMAX; i++) {
      if(!StringCompare(symbols4H[i], s)) {
        return i;
      }
    }
  }

  return -1;
}


void setText() {

  string lbl = "4H: " + symbols4H[0];
  for(int i = 1; i < iMAX; i++) {
    lbl += " > " + symbols4H[i];
  }
  ObjectSetText(status4H, lbl, 12, "Arial", clrYellow);

  lbl = "1D: " + symbols1D[0];
  for(int i = 1; i < iMAX; i++) {
    lbl += " > " + symbols1D[i];
  }
  ObjectSetText(status1D, lbl, 12, "Arial", clrYellow);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {

  minLot = MarketInfo(Symbol(), MODE_MINLOT);
  maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
  lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
  lotSize = MarketInfo(Symbol(), MODE_LOTSIZE);
  
  assignIndex();  
  sortSymbols();
  drawLabel();
  setText();
  symbolSignal();
  
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  ObjectDelete(status4H);
  ObjectDelete(status1D);
  
  for(int i = 0; i < 5; i++) 
    ObjectDelete(standby[i]);      
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
  sortSymbols();
  setText();
  symbolSignal();
    
  if(AccountEquity() < Equity_StopLoss) {
    for(int i = 0; i < OrdersTotal(); i++) {      
      if(OrderSelect(i, SELECT_BY_POS)) {
        if(OrderMagicNumber() == Magic_Number) {
             
          if(OrderType() == OP_BUY) {
            if(!OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(MarketInfo(OrderSymbol(), MODE_BID), Digits), 3)) {
              Print("Error on closing long order: ", GetLastError());
            }
            else {
              i = -1;
            }
          }
          else if(OrderType() == OP_SELL) {
            if(!OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(MarketInfo(OrderSymbol(), MODE_ASK), Digits), 3)) {
              Print("Error on closing short order: ", GetLastError());
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
  
  for(int i = 0; i < 15; i++) {
    hasPositions[i] = False;
  }

  
  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(OrderMagicNumber() == Magic_Number) {
        int direction = OrderType();

        for(int j = 0; j < 15; j++) {
          if(!StringCompare(possiblePairs[j], OrderSymbol())) {
            hasPositions[j] = True;

            double maL1 = iMA(possiblePairs[j], EMA_Time_Frame, EMA_Close_L_Period, 0, MODE_EMA, PRICE_WEIGHTED, 1);
            double maL2 = iMA(possiblePairs[j], EMA_Time_Frame, EMA_Close_L_Period, 0, MODE_EMA, PRICE_WEIGHTED, 2);
            double maM1 = iMA(possiblePairs[j], EMA_Time_Frame, EMA_Close_M_Period, 0, MODE_EMA, PRICE_WEIGHTED, 1);
            double maM2 = iMA(possiblePairs[j], EMA_Time_Frame, EMA_Close_M_Period, 0, MODE_EMA, PRICE_WEIGHTED, 2);
            double maS1 = iMA(possiblePairs[j], EMA_Time_Frame, EMA_Close_S_Period, 0, MODE_EMA, PRICE_WEIGHTED, 1);
            double maS2 = iMA(possiblePairs[j], EMA_Time_Frame, EMA_Close_S_Period, 0, MODE_EMA, PRICE_WEIGHTED, 2);
          
            if(EMA_Exit) {
              if(direction == OP_BUY) {
                if(/*maL2 < maS2 && */maM2 < maS2 && /*maL1 > maS1 && */maM1 > maS1) {
                  bool closed = OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(MarketInfo(OrderSymbol(), MODE_BID), Digits), 3);
                }
              }
              else if(direction == OP_SELL) {
                if(/*maL2 > maS2 && */maM2 > maS2 && /*maL1 < maS1 && */maM1 < maS1) {       
                  bool closed = OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(MarketInfo(OrderSymbol(), MODE_ASK), Digits), 3);
                }
              }
            }
          }
        }
      }
    }
  }


  double equity = AccountEquity();

  if(equity < Min_Equity_For_Entry) {
    Print("Account Equity is too low: " + DoubleToString(equity, 0) + " (< " + IntegerToString(Min_Equity_For_Entry) + ")");
    return;
  }
  else if(Equity_TakeProfit < equity) {
    Print("Account Equity is too high: " + DoubleToString(equity, 0) + " (< " + IntegerToString(Equity_TakeProfit) + ")");
    return;
  }
  
  if(!Friday_PM_Entry && DayOfWeek() == 5 && 18 <= TimeHour(TimeLocal())) {
    return;
  }

  if(PB_setting) {
    for(int i = 0; i < 15; i++) {
      if(!hasPositions[i]) {
          
        double tp = TP * MarketInfo(possiblePairs[i], MODE_POINT) * 10;
        double sl = SL * MarketInfo(possiblePairs[i], MODE_POINT) * 10;
      
        if(signals[i] == OP_BUY) {
          double price = MarketInfo(OrderSymbol(), MODE_ASK);
          int ticket = OrderSend(possiblePairs[i], OP_BUY, calcLot(), NormalizeDouble(price, Digits), 3, NormalizeDouble(price - sl, Digits), NormalizeDouble(price + tp, Digits), NULL, Magic_Number);
        }
        else if(signals[i] == OP_SELL) {        
          double price = MarketInfo(OrderSymbol(), MODE_BID);
          int ticket = OrderSend(possiblePairs[i], OP_SELL, calcLot(), NormalizeDouble(price, Digits), 3, NormalizeDouble(price + sl, Digits), NormalizeDouble(price - tp, Digits), NULL, Magic_Number);
        }
      }
    }
  }
  else {
    double maL1 = iMA(Symbol(), PERIOD_CURRENT, EMA_Close_L_Period, 0, MODE_EMA, PRICE_WEIGHTED, 1);
    double maL2 = iMA(Symbol(), PERIOD_CURRENT, EMA_Close_L_Period, 0, MODE_EMA, PRICE_WEIGHTED, 2);
    double maM1 = iMA(Symbol(), PERIOD_CURRENT, EMA_Close_M_Period, 0, MODE_EMA, PRICE_WEIGHTED, 1);
    double maM2 = iMA(Symbol(), PERIOD_CURRENT, EMA_Close_M_Period, 0, MODE_EMA, PRICE_WEIGHTED, 2);
    double maS1 = iMA(Symbol(), PERIOD_CURRENT, EMA_Close_S_Period, 0, MODE_EMA, PRICE_WEIGHTED, 1);
    double maS2 = iMA(Symbol(), PERIOD_CURRENT, EMA_Close_S_Period, 0, MODE_EMA, PRICE_WEIGHTED, 2);

    double tp = TP * Point * 10;
    double sl = SL * Point * 10;
          
    if(maL2 < maS2 && maM2 < maS2 && maL1 > maS1 && maM1 > maS1) {
      int ticket = OrderSend(Symbol(), OP_SELL, calcLot(), NormalizeDouble(Bid, Digits), 3, NormalizeDouble(Bid + sl, Digits), NormalizeDouble(Bid - tp, Digits), NULL, Magic_Number);
    }
    if(maL2 > maS2 && maM2 > maS2 && maL1 < maS1 && maM1 < maS1) {       
      int ticket = OrderSend(Symbol(), OP_BUY, calcLot(), NormalizeDouble(Ask, Digits), 3, NormalizeDouble(Ask - sl, Digits), NormalizeDouble(Ask + tp, Digits), NULL, Magic_Number);
    }
  }
}
