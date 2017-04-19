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

input bool PB_setting = True;
input int PB_distance = 2;
input bool GBP = True;
input bool EUR = True;
input bool CHF = False;
input bool AUD = True;
input bool USD = True;
input bool JPY = True;

string possiblePairs[] = {"USDJPY", "EURJPY", "GBPJPY", "AUDJPY", "EURUSD", 
                          "GBPUSD", "AUDCHF", "EURCHF", "GBPCHF", "USDCHF",
                          "CHFJPY", "EURAUD", "EURGBP", "GBPAUD", "AUDUSD"};

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

void symbolSignal() {

  string lbl[] = {"Stand By:", "             ", "             ", "             ", "             "};
  double idx = -0.1;
  
  for(int i = 0; i < 15; i++) {
    int d0 = getIndex(StringSubstr(possiblePairs[i], 0, 3), True);
    int d3 = getIndex(StringSubstr(possiblePairs[i], 3, 3), True);
    if(d0 == -1 || d3 == -1) {
      continue;
    }

    int h0 = getIndex(StringSubstr(possiblePairs[i], 0, 3), False);
    int h3 = getIndex(StringSubstr(possiblePairs[i], 3, 3), False);
    
    if(PB_distance < d0 - d3) {
      if(PB_distance < h0 - h3) {
        idx += 1.0;
        lbl[int(MathFloor(idx / 3.0))] += ", sell " + possiblePairs[i];
      }
    }
    if(PB_distance < d3 - d0) {
      if(PB_distance < h3 - h0) {
        idx += 1.0;
        lbl[int(MathFloor(idx / 3.0))] += ", buy " + possiblePairs[i];
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
     
}
