import processing.pdf.*;

// Modes
final int SETUP = 0;
final int INPUT = 1;
final int FLIP = 2;
final int NUM_MODES = 3;

// Directions
final int N = 0; // North
final int W = 1; // West
final int S = 2; // South
final int E = 3; // East
final int X = 4; // None
final int U = 5; // Unassigned
final int T = 6; // Tree

// Crease Assignment
final int UN =  0; // Unassigned
final int MT =  1; // Mountain
final int VY = -1; // Valley
// Absolute Direction
final int PS =  1; // Positive
final int NG = -1; // Negative

// Intial Map Parameters
final int START_H = 4;
final int START_W = 5;

// Layout Constants
final int OFFSET = 100;
final int RAD = 16;
final int MAXDIM = 9;
final int MAXSIZE = 550;

Map map;
PGraphicsPDF pdf;
int ct;
boolean recordPDF;

void setup() {
  // size(MAXSIZE*2+OFFSET*3, MAXSIZE+OFFSET*2)
  size(1400, 750);
  pixelDensity(2);
  map = new Map();
  map.mode = SETUP;
  ct = 1;
  recordPDF = false;
  draw(); noLoop();
}

void draw() {
  if (recordPDF) {
    beginRecord(PDF, "output/mapout-"+ct+".pdf");
    //textMode(MODEL);
    //textFont(createFont("LucidaGrande", 12), 14);
    map.display(); ct++;
    endRecord();
  } else {
    map.display();
  }
} 

void keyPressed() {
  map.error = "";
  switch (key) {
    case 'c': map.update(); break;
    case 'r': map.randAssign(); break;
    case 'v': map.showVerts = !map.showVerts; break;
    case 'e': map.showEdges = !map.showEdges; break;
    case 'f': map.showFaces = !map.showFaces; break;
    case 'p': recordPDF = !recordPDF; break;
    case 's': map.toggleDisp(); break;
    case 'm': map.toggleMode(); break;
  }
  switch (map.mode) {
    case SETUP:
      switch (key) {
        case CODED:
          switch (keyCode) {
            case RIGHT: map.chgDim( 0, 1); break;
            case LEFT:  map.chgDim( 0,-1); break;
            case UP:    map.chgDim( 1, 0); break;
            case DOWN:  map.chgDim(-1, 0); break;
          } break;
      } break;
    case INPUT:
      switch (key) {
        case BACKSPACE: map.popA(); break;
        case DELETE:    map.popA(); break;
        case CODED:
          switch (keyCode) {
            case RIGHT: map.pushA(E); break;
            case LEFT:  map.pushA(W); break;
            case UP:    map.pushA(N); break;
            case DOWN:  map.pushA(S); break;
          } break;
      } break;
    case FLIP:
      switch (key) {
        case CODED:
          switch (keyCode) {
            case RIGHT: map.select(PS); break;
            case LEFT:  map.select(NG); break;
            case UP:    map.flip(PS); break;
            case DOWN:  map.flip(NG); break;
          } break;
      } 
      //map.updateEdges();
      break;
  } redraw();
}

void mouseClicked() {
  map.clearSel();
  float mx = (mouseY - map.y)/map.sc;
  float my = (mouseX - map.x)/map.sc;
  int rmx = round(mx);
  int rmy = round(my);
  int hmx = round(mx-0.5);
  int hmy = round(my-0.5);
  if (rmx <= map.h+1 && rmx >= 0 &&
      rmy <= map.w+1 && rmy >= 0) {
    if (abs(rmx-mx) < RAD/map.sc/2 &&  // Check Vertices
        abs(rmy-my) < RAD/map.sc/2 && map.showVerts) {
      map.vs = map.v[rmx][rmy];
      map.vs.s = true;
    } 
    if (abs(hmx-mx+0.5) < RAD/map.sc/2 && // Check Faces
        abs(hmy-my+0.5) < RAD/map.sc/2 && map.showFaces) {
      map.fs = map.f[hmx][hmy];
      map.fs.s = true;
    } 
    if (abs(hmx-mx+0.5) < RAD/map.sc/2 && // Check Vertical Edges
        abs(rmy-my) < RAD/map.sc/2 && map.showEdges) { 
      map.es = map.vE[hmx][rmy];
      map.es.s = true;
    }
    if (abs(rmx-mx) < RAD/map.sc/2 && // Check Horizontal Edges
        abs(hmy-my+0.5) < RAD/map.sc/2 && map.showEdges) { 
      map.es = map.hE[rmx][hmy];
      map.es.s = true;
    }
  } 
  mx = -(mouseY - map.maxSize - OFFSET)/map.tsc;
  my = (mouseX - map.maxSize - 2*OFFSET)/map.tsc;
  rmx = round(mx);
  rmy = round(my);
  if (rmx < (map.h+1)*(map.w+1) && rmx >= rmy &&
      rmy < (map.h+1)*(map.w+1) && rmy >= 0) {
    if (rmx == rmy &&
        abs(rmx-mx) < 1./3 &&
        abs(rmy-my) < 1./3) {
      map.fs = map.f[map.order[rmx][0]][map.order[rmx][1]];
      map.fs.s = true;
    }
    if (rmx != rmy &&
        abs(rmx-mx) < 1./3 &&
        abs(rmy-my) < 1./3) {
      Face f1 = map.f[map.order[rmx][0]][map.order[rmx][1]];
      Face f2 = map.f[map.order[rmy][0]][map.order[rmy][1]];
      for (int i = 0; i < 4; i++) {
        if (f1.e[i] == f2.e[(i+2)%4]) {
          if (map.dispTok >= U || map.dispTok == f1.e[i].t) {
            map.es = f1.e[i];
            map.es.s = true;
            break;
          }
        }
      }
    }
  }
  redraw();
}

class Map {
  int mode;            // Mode tracker
  int x, y;            // X/Y of top-left corner
  float sc, tsc;
  int h, w;            // Height and Width of grid
  int maxDim, maxSize; // largest grid dimension and space
  Vert[][] v;          // Vertex Array
  Face[][] f;          // Face Array
  Edge[][] hE;         // Array of horizontal edges
  Edge[][] vE;         // Array of vertical edges
  String error;
  int[][] order;
  
  boolean showVerts;
  boolean showEdges;
  boolean showFaces;
  boolean global;
  int dispTok;
  
  Vert vs;
  Edge es;
  Face fs;
  
  int a;  // number of already assigned vertices
  int numCrs;
 
  Map() {
    x = OFFSET;
    y = OFFSET;
    h = START_H;
    w = START_W;
    maxDim = MAXDIM;
    maxSize = MAXSIZE;
    error = "";
    order = new int[(h+1)*(w+1)][2];
    showVerts = false;
    showEdges = false;
    showFaces = false;
    global = false;
    dispTok = X;
    numCrs = 0;
    update();
  }
  
  void toggleMode() {
    mode = (mode + 1) % NUM_MODES;
  }
  
  void toggleDisp() {
    dispTok = (dispTok + 1) % 6;
  }
  
  void calcScale() {
    sc = min(float(maxSize)/(h+1),float(maxSize)/(w+1));
    tsc = float(maxSize)/((h+1)*(w+1)-1);
  }
  
  void update() {
    a = 0;
    clearSel();
    calcScale();
    v = new Vert[h+2][w+2];   // Init vertex array
    f = new Face[h+1][w+1];   // Init face array
    hE = new Edge[h+2][w+1];  // Init horizontal edges
    vE = new Edge[h+1][w+2];  // Init vertical edges
    initVerts();
    initFaces();
    initEdges();
    connVerts();
    connFaces();
    connEdges();
  }
  
  void initVerts() {
    for (int i = 0; i < h+2; i++) {
      for (int j = 0; j < w+2; j++) {
        v[i][j] = new Vert(this,i,j); // Populate vertices
      }
    }
  }
  
  void initFaces() {
    for (int i = 0; i < h+1; i++) {
      for (int j = 0; j < w+1; j++) {
        f[i][j] = new Face(this,i,j); // Populate faces
      }
    }
  }
  
  void initEdges() {
    for (int i = 0; i < h+2; i++) {
      for (int j = 0; j < w+2; j++) {
        if (i <= h) {
          vE[i][j] = new Edge(this,i,j,N); // Populate vert edges
        }
        if (j <= w) {
          hE[i][j] = new Edge(this,i,j,E); // Populate horz edges
        }
      }
    }
  }
  
  void connVerts() {
    for (int i = 0; i < h+2; i++) {
      for (int j = 0; j < w+2; j++) {
        v[i][j].connect(); // Populate vertices
      }
    }
  }
  
  void connFaces() {
    for (int i = 0; i < h+1; i++) {
      for (int j = 0; j < w+1; j++) {
        f[i][j].connect(); // Populate faces
      }
    }
  }
  
  void connEdges() {
    for (int i = 0; i < h+2; i++) {
      for (int j = 0; j < w+2; j++) {
        if (i <= h) {
          vE[i][j].connect(); // Populate vert edges
        }
        if (j <= w) {
          hE[i][j].connect(); // Populate horz edges
        }
      }
    }
  }
  
  void chgDim(int dh, int dw) { 
    if (h+dh < 1 || w+dw < 1) {
      error = "Sorry, must have at least one internal vertex.";
    } else if (h+dh > maxDim || w+dw > maxDim) {
      error = "Sorry, reached internal vertex limit of "+maxDim+".";
    } else {
      h = h+dh;
      w = w+dw;
    }
    update();
  }
  
  void pushA(int dir) {
    if (a < h*w) {
      int ay = a % w;
      int ax = (a - ay)/w;
      boolean valid = v[ax+1][ay+1].setT(dir); // Check MV Assignment
      if (valid) {
        boolean cycle = linearize();
        if (cycle) {
          v[ax+1][ay+1].setT(U);
          error = "Sorry, that would create a cycle.";
        } else {
          a++;
        }
      } else {
        error = "Sorry, no valid M/V assignment."; 
      }
    } else {
      error = "Sorry, no more vertices to assign.";
    }
  }

  void popA() {
    if (a > 0) {
      a--;
      int aw = a % w;
      int ah = (a - aw)/w;
      v[ah+1][aw+1].setT(U);
      linearize();
    } else {
      error = "Sorry, no more vertices to remove.";
    }
  }
  
  boolean linearize() {
    boolean cycle = false;
    int[][] ord = new int[h+1][w+1];
    int k = 1;
    for (int i = 0; i < h+1; i++) {
      for (int j = 0; j < w+1; j++) {
        if (ord[i][j] == 0) {
          //println(k+","+i+","+j);
          int gN = f[i][j].e[N].g; 
          int gW = f[i][j].e[W].g; 
          int gS = f[i][j].e[S].g; 
          int gE = f[i][j].e[E].g;
          boolean all = gN == 0 && gW == 0 && gS == 0 && gE == 0;
          //println(gN+","+gW+","+gS+","+gE);
          if (all) { ord[i][j] = -1; } 
          else {
            boolean bN = gN <= 0 || (gN == PS && ord[i-1][j] > 0);
            boolean bW = gW <= 0 || (gW == PS && ord[i][j-1] > 0);
            boolean bS = gS >= 0 || (gS == NG && ord[i+1][j] > 0);
            boolean bE = gE >= 0 || (gE == NG && ord[i][j+1] > 0);
            //println(bN+","+bW+","+bS+","+bE);
            if (bN && bW && bS && bE) { 
              ord[i][j] = k; 
              i = 0; j = -1; k++; 
            }
          }
        }
      }
    }
    order = new int[k-1][2];
    for (int i = 0; i < h+1; i++) {
      for (int j = 0; j < w+1; j++) {
        if (ord[i][j] == 0) {
          cycle = true;
        } else if (ord[i][j] > 0) {
          order[ord[i][j]-1][0] = i;
          order[ord[i][j]-1][1] = j;
        }
      }
    }
    if (!cycle) {
      for (int i = 0; i < h+1; i++) {
        for (int j = 0; j < w+1; j++) {
          f[i][j].setL(max(ord[i][j],0));
        }
      }
    }
    return cycle;
  }
  
  void display() {
    background(255);
    displayEdges();
    displayVerts();
    displayFaces();
    displayTokens();
    displayIntersect();
    displayInfo();
  }
  
  void displayInfo() {
    noStroke(); fill(0);
    textSize(14); textAlign(LEFT, CENTER);
    String str = "Map Folding v2.0 (C) 2015 Jason S. Ku -- ";
    str += "(P) Record to PDF: [";
    if (recordPDF) {
      str += "ON]";
    } else {
      str += "OFF]";
    }
    text(str,OFFSET,OFFSET*0.25);
    str = "(M) Change mode: ";
    switch (mode) {
      case SETUP: 
        str += "[Setup] Arrows change grid dimensions";
        break;
      case INPUT: 
        str += "[Input] Arrows assign next vertex, Delete removes.";
        break;
      case FLIP: 
        str += "[Flip] Left/Right selects, Up/Down flips above/below.";
        break;
    }
    text(str,OFFSET,OFFSET*0.5);
    str = "Click on circles to select. Internal vertex grid: "+h+"x"+w;
    text(str,OFFSET,OFFSET*0.75);
    str = "(V/E/F) Toggle show Vertices/Edges/Faces, currently ";
    if (showVerts) { str += "ON/"; } else { str += "OFF/"; }
    if (showEdges) { str += "ON/"; } else { str += "OFF/"; }
    if (showFaces) { str += "ON"; } else { str += "OFF"; }
    str += " respectively.";
    text(str,OFFSET,maxSize+1.25*OFFSET);
    str = "(R) Create random M/V assignment (C) Clear M/V assignment";
    text(str,OFFSET,maxSize+1.5*OFFSET);
    str = "Message: "+error;
    text(str,OFFSET,maxSize+1.75*OFFSET);
    textAlign(RIGHT, CENTER);
    str = "(S) Toggle Token view";
    text(str,2*maxSize+2*OFFSET,maxSize+1.25*OFFSET);
    str = "[";
    switch (dispTok) {
      case U: str += "All";   break;
      case N: str += "North"; break;
      case W: str += "West";  break;
      case S: str += "South"; break;
      case E: str += "East";  break;
      case T: str += "Tree";  break;
      case X: str += "None";  break;
    }
    str += " View]";
    text(str, 2*maxSize+2*OFFSET,maxSize+1.5*OFFSET);
    if (a != 0) {
      if (global) {
        str = "Globally flat-foldable state!";
      } else {
        str = numCrs+" intersections in this folded state.";
      }
      text(str, 2*maxSize+2*OFFSET,maxSize+1.75*OFFSET);
    }
  }
  
  void displayVerts() {
    if (showVerts) {
      for (int i = 0; i < h+2; i++) {
        for (int j = 0; j < w+2; j++) {
          v[i][j].display();
        }
      }
    }
  }
  
  void displayEdges() {
    for (int i = 0; i < h+2; i++) {
      for (int j = 0; j < w+2; j++) {
        if (i <= h) {
          vE[i][j].display();
        }
        if (j <= w) {
          hE[i][j].display();
        }
      }
    }
  }
  
  void displayFaces() {
    if (showFaces) {
      for (int i = 0; i < h+1; i++) {
        for (int j = 0; j < w+1; j++) {
          f[i][j].display();
        }
      }
    }
  }
  
  void displayGrid() {
    float ext = float(maxSize);
    float sft = float(OFFSET);
    stroke(240); noFill();
    for (int i = 0; i < (h+1)*(w+1); i++) {
      line(ext+2*sft,sft+i*tsc,2*ext+2*sft,sft+i*tsc);
      line(ext+2*sft+i*tsc,sft,ext+2*sft+i*tsc,sft+ext);
    }
    stroke(0); noFill();
    line(ext+2*sft,sft+ext,2*ext+2*sft,sft);
  }
  
  void displayTokens() {
    displayGrid();
    for (int i = 0; i < h+2; i++) {
      for (int j = 0; j < w+2; j++) {
        if (i <= h) {
          vE[i][j].update();
        }
        if (j <= w) {
          hE[i][j].update();
        }
      }
    }
    for (int i = 0; i <= h; i++) {
      for (int j = 0; j <= w; j++) {
        v[i][j].displayToken();
      }
    }
    for (int i = 0; i < h+2; i++) {
      for (int j = 0; j < w+2; j++) {
        if (i <= h) {
          vE[i][j].displayLines();
        }
        if (j <= w) {
          hE[i][j].displayLines();
        }
      }
    }
    for (int i = 0; i < h+2; i++) {
      for (int j = 0; j < w+2; j++) {
        if (i <= h) {
          vE[i][j].displayToken();
        }
        if (j <= w) {
          hE[i][j].displayToken();
        }
        if (i <= h && j <= w) {
          f[i][j].displayToken();
        }
      }
    }
  }
  
  void displayIntersect() {
    numCrs = 0;
    global = true;
    Edge vE1, vE2, hE1, hE2;
    for (int i = 0; i < h+2; i++) {
      for (int j = 0; j < w+2; j++) {
        for (int k = 0; k < h+2; k++) {
          for (int l = 0; l < w+2; l++) {
            if (k <= h && i <= h) { 
              vE1 = vE[i][j]; vE2 = vE[k][l]; 
              drawIntersect(vE1.intersect(vE2),vE1,vE2);
            }
            if (l <= w && j <= w) { 
              hE1 = hE[i][j]; hE2 = hE[k][l];
              drawIntersect(hE1.intersect(hE2),hE1,hE2);
            }
          }
        }
      }
    }
  }
  
  void drawIntersect(int cr, Edge e1, Edge e2) {
    float r = tsc/3;
    noFill(); stroke(0); strokeWeight(2); 
    if (cr != 0) { 
      numCrs++;
      global = false;
      if (dispTok == e1.t || dispTok == U) {
        switch (cr) {
          case 1: 
            ellipse(e2.f1.tx,e1.f2.ty,r,r); 
            break;
          case 2: 
            ellipse(e2.f2.tx,e1.f2.ty,r,r); 
            break;
          case 3: 
            ellipse(e2.f1.tx,e1.f1.ty,r,r); 
            break;
          case 4: 
            ellipse(e2.f2.tx,e1.f1.ty,r,r); 
            break;
        }
      }
    }
    strokeWeight(1);
  }
  
  void updateEdges() {
    for (int i = 0; i < h+2; i++) {
      for (int j = 0; j < w+2; j++) {
        if (i <= h) {
          vE[i][j].update();
        }
        if (j <= w) {
          hE[i][j].update();
        }
      }
    }
  }
  
  void randAssign() {
    update();
    while (a < h*w) {
      pushA(floor(random(4)));
    }
    error = "";
  }
  
  void clearSel() {
    if (vs != null) { vs.s = false; vs = null; }
    if (es != null) { es.s = false; es = null; }
    if (fs != null) { fs.s = false; fs = null; }
  }
  
  void select(int dir) {
    if (fs != null) {
      fs.s = false;
      int o = (fs.l-1+dir+order.length) % order.length;
      fs = f[order[o][0]][order[o][1]];
      fs.s = true;
    } else {
      fs = f[order[0][0]][order[0][1]];
      fs.s = true;
    }
  }
  
  void flip(int dir) {
    if (fs != null && fs.l-1+dir < order.length && fs.l-1+dir >= 0) {
      Face ff = f[order[fs.l-1+dir][0]][order[fs.l-1+dir][1]];
      boolean notAdjacent = true;
      for (int i = 0; i < 4; i++) {
        if (fs.e[i] == ff.e[(i+2)%4]) {
          notAdjacent = false; break;
        }
      }
      if (notAdjacent) {
        int temp = fs.l;
        fs.setL(ff.l); ff.setL(temp);
        order[fs.l-1][0] = fs.x; order[fs.l-1][1] = fs.y;
        order[ff.l-1][0] = ff.x; order[ff.l-1][1] = ff.y;
      } else {
        error = "Sorry, flipping would reverse an edge.";
      }
    }
  }
} 

class Vert {
  Map m;
  int  x,  y;
  float px, py;
  int t; // Type
  boolean s;
  Edge[] e; // NWSE
  
  Vert(Map m, int x, int y) {
    this.m = m;
    this.x = x; this.y = y;
    px = m.y+y*m.sc;
    py = m.x+x*m.sc;
    t = U;
    s = false;
    e = new Edge[4];
  }
  
  void connect() {
    if (x != 0)     { e[N] = m.vE[x-1][y]; }
    if (y != 0)     { e[W] = m.hE[x][y-1]; }
    if (x != m.h+1) { e[S] = m.vE[x][y];   }
    if (y != m.w+1) { e[E] = m.hE[x][y];   }
  }

  boolean setT(int dir) {
    boolean okay = true;
    switch (dir) {
      case U:
        e[S].a = UN; e[E].a = UN;
        if (x == 1) { e[N].a = UN; }
        if (y == 1) { e[W].a = UN; }
        e[S].g = UN; e[E].g = UN;
        if (x == 1) { e[N].g = UN; }
        if (y == 1) { e[W].g = UN; }
        break;
      case N:
        if (e[N].a == UN && e[W].a == UN) { // First assignment
          e[N].a = VY; e[W].a = MT; e[S].a = MT; e[E].a = MT;
          e[N].g = PS; e[W].g = NG; e[S].g = PS; e[E].g = PS; }
        else if (e[N].a == UN && e[W].a != UN) {
          int A = e[W].a; e[N].a = -A; e[S].a = A; e[E].a = A; 
          int G = -e[W].g; e[N].g = G; e[S].g = G; e[E].g = G; }
        else if (e[N].a != UN && e[W].a == UN) {
          int A = -e[N].a; e[W].a = A; e[S].a = A; e[E].a = A; 
          int G = e[N].g; e[W].g = -G; e[S].g = G; e[E].g = G; }
        else if (e[N].a != UN && e[W].a != UN && e[N].a != e[W].a) {
          int A = e[W].a; e[S].a = A; e[E].a = A; 
          int G = e[N].g; e[S].g = G; e[E].g = G;} 
        else if (e[N].a != UN && e[W].a != UN && e[N].a == e[W].a) {
          okay = false; } break;
      case W:
        if (e[N].a == UN && e[W].a == UN) { // First assignment
          e[N].a = VY; e[W].a = MT; e[S].a = VY; e[E].a = VY; 
          e[N].g = PS; e[W].g = NG; e[S].g = NG; e[E].g = NG; }  
        else if (e[N].a == UN && e[W].a != UN) {
          int A = -e[W].a; e[N].a = A; e[S].a = A; e[E].a = A; 
          int G = e[W].g; e[N].g = -G; e[S].g = G; e[E].g = G; }
        else if (e[N].a != UN && e[W].a == UN) {
          int A = e[N].a; e[W].a = -A; e[S].a = A; e[E].a = A; 
          int G = -e[N].g; e[W].g = G; e[S].g = G; e[E].g = G; }
        else if (e[N].a != UN && e[W].a != UN && e[N].a != e[W].a) {
          int A = e[N].a; e[S].a = A; e[E].a = A; 
          int G = e[W].g; e[S].g = G; e[E].g = G; }
        else if (e[N].a != UN && e[W].a != UN && e[N].a == e[W].a) {
          okay = false; } break;
      case S:
        if (e[N].a == UN && e[W].a == UN) { // First assignment
          e[N].a = VY; e[W].a = VY; e[S].a = MT; e[E].a = VY; 
          e[N].g = PS; e[W].g = PS; e[S].g = PS; e[E].g = NG; } 
        else if (e[N].a == UN && e[W].a != UN) {
          int A = e[W].a; e[N].a = A; e[S].a = -A; e[E].a = A; 
          int G = e[W].g; e[N].g = G; e[S].g = G; e[E].g = -G; }
        else if (e[N].a != UN && e[W].a == UN) {
          int A = e[N].a; e[W].a = A; e[S].a = -A; e[E].a = A; 
          int G = e[N].g; e[W].g = G; e[S].g = G; e[E].g = -G; }
        else if (e[N].a != UN && e[W].a != UN && e[N].a == e[W].a) {
          int A = e[N].a; e[S].a = -A; e[E].a = A;
          int G = e[N].g; e[S].g = G; e[E].g = -G; }
        else if (e[N].a != UN && e[W].a != UN && e[N].a != e[W].a) {
          okay = false; } break;
      case E:
        if (e[N].a == UN && e[W].a == UN) { // First assignment
          e[N].a = VY; e[W].a = VY; e[S].a = VY; e[E].a = MT;
          e[N].g = PS; e[W].g = PS; e[S].g = NG; e[E].g = PS; } 
        else if (e[N].a == UN && e[W].a != UN) {
          int A = e[W].a; e[N].a = A; e[S].a = A; e[E].a = -A; 
          int G = e[W].g; e[N].g = G; e[S].g = -G; e[E].g = G; }
        else if (e[N].a != UN && e[W].a == UN) {
          int A = e[N].a; e[W].a = A; e[S].a = A; e[E].a = -A; 
          int G = e[N].g; e[W].g = G; e[S].g = -G; e[E].g = G; }
        else if (e[N].a != UN && e[W].a != UN && e[N].a == e[W].a) {
          int A = e[N].a; e[S].a = A; e[E].a = -A;
          int G = e[N].g; e[S].g = -G; e[E].g = G; }
        else if (e[N].a != UN && e[W].a != UN && e[N].a != e[W].a) {
          okay = false; } break;
    }
    if (okay) { t = dir; }
    return okay;
  }

  void display() {
    if (t != U) {
      if (s) { 
        strokeWeight(2);
        stroke(255,0,0); noFill();
        ellipse(px,py,1.5*RAD,1.5*RAD);
        strokeWeight(1);
        fill(255,255,0);
      } else { fill(255); }
      stroke(128); 
      ellipse(px,py,RAD,RAD);
      String str = str(t);
      switch (t) { 
        case U: str = " "; break;
        case N: str = "N"; break;
        case W: str = "W"; break;
        case S: str = "S"; break;
        case E: str = "E"; break;
      }
      noStroke(); fill(0);
      textSize(10); textAlign(CENTER, CENTER);
      text(str,px,py);
    }
  }
  
  void displayToken() {
    if (s && t != U && m.showVerts) {
      noStroke(); fill(255,255,0,100);
      Edge e1 = e[t];
      Edge e2 = e[(t+1) % 4];
      Edge e3 = e[(t+2) % 4];
      Edge e4 = e[(t+3) % 4];
      Face f12, f14;
      if (e1.f1 == e2.f1 || e1.f1 == e2.f2) {
        f12 = e1.f1; f14 = e1.f2;
      } else {
        f12 = e1.f2; f14 = e1.f1;
      }
      triangle(e3.tx,e3.ty,e2.tx,e2.ty,e1.tx,e1.ty);
      triangle(e3.tx,e3.ty,e4.tx,e4.ty,e1.tx,e1.ty);
      triangle(f12.tx,f12.ty,e1.tx,e1.ty,e2.tx,e2.ty);
      triangle(f14.tx,f14.ty,e1.tx,e1.ty,e4.tx,e4.ty);
      stroke(0); noFill();
      line(e3.tx,e3.ty,e2.tx,e2.ty);
      line(e3.tx,e3.ty,e4.tx,e4.ty);
      line(e2.tx,e2.ty,f12.tx,f12.ty);
      line(e4.tx,e4.ty,f14.tx,f14.ty);
      line(e1.tx,e1.ty,f12.tx,f12.ty);
      line(e1.tx,e1.ty,f14.tx,f14.ty);
    }
    if (t != U && (m.dispTok == T || m.dispTok == e[t].t)) {
      Edge e1 = e[t];
      Edge e2 = e[(t+1) % 4];
      Edge e3 = e[(t+2) % 4];
      Edge e4 = e[(t+3) % 4];
      strokeWeight(2);
      switch (e1.t) { 
        case N: stroke(255,64,64); break;
        case W: stroke( 0,200, 0); break;
        case S: stroke(255,128,0); break;
        case E: stroke(0,128,255); break;
      } 
      stroke(255,255,0);
      noFill();
      line(e1.tx,e1.ty,e3.tx,e3.ty);
      //stroke(0);
      //line(e3.tx,e3.ty,e2.tx,e2.ty);
      //line(e3.tx,e3.ty,e4.tx,e4.ty);
      strokeWeight(1);
    }
  }
}

class Face {
  Map m;
  int  x,  y;
  float tx, ty;
  float px, py;
  int l; // Layer
  boolean s;
  Edge[] e; // NSEW
  
  Face(Map m, int x, int y) {
    this.m = m;
    this.x = x; this.y = y;
    px = m.y+(y+0.5)*m.sc;
    py = m.x+(x+0.5)*m.sc;
    e = new Edge[4];
    l = 0;
    s = false;
  }
  
  Face(Map m) {
    this.m = m;
    l = 0;
    s = false;
  }
  
  void connect() {
    e[N] = m.hE[x][y];
    e[W] = m.vE[x][y];
    e[S] = m.hE[x+1][y];
    e[E] = m.vE[x][y+1];
  }
  
  void setL(int l) {
    this.l = l;
    float ext = float(m.maxSize);
    float sft = float(OFFSET);
    tx = ext+2*sft+(l-1)*m.tsc;
    ty = sft+ext-(l-1)*m.tsc;
  }
  
  void display() {
    if (l != 0) {
      if (s) { 
        strokeWeight(2);
        stroke(255,0,0); noFill();
        ellipse(px,py,1.5*RAD,1.5*RAD);
        strokeWeight(1);
        fill(255,255,0);
      } else { fill(255); }
      stroke(128);
      ellipse(px,py,RAD,RAD);
      String str = str(l);
      if (l == 0) { str = " "; }
      noStroke(); fill(0);
      textSize(10); textAlign(CENTER, CENTER);
      text(str,px,py);
    }
  }
  
  void displayToken() {
    if (l > 0 && m.dispTok != X) {
      if (s) { 
        stroke(0); fill(255,255,0);
        ellipse(tx,ty,m.tsc/1.5,m.tsc/1.5);
        strokeWeight(2);
        stroke(255,0,0); noFill();
        ellipse(tx,ty,m.tsc,m.tsc);
        strokeWeight(1);
      } else {
        noStroke(); fill(0);
        ellipse(tx,ty,m.tsc/1.5,m.tsc/1.5);
      }
    }
  }
}

class Edge {
  Map m;
  Vert v1, v2;
  Face f1, f2;
  int  x,  y;
  float px, py;
  float tx, ty;
  int t; // Type
  int g; // Direction of up gradient
  int a; // Assignment
  boolean s;
  
  Edge(Map m, int x, int y, int dir) {
    this.m = m; 
    this.x = x; 
    this.y = y;
    f1 = new Face(m);
    f2 = new Face(m);
    t = dir; g = UN; 
    a = UN; s = false;
    px = m.y+y*m.sc; 
    py = m.x+x*m.sc;
    switch (dir) {
      case N: case S:
        py += m.sc/2; break;
      case E: case W:
        px += m.sc/2; break;
    }
  }
  
  void connect() {
    switch (t) {
      case N: case S:
        v1 = m.v[x][y];
        v2 = m.v[x+1][y];
        if (y != 0)     { f1 = m.f[x][y-1]; } 
        if (y != m.w+1) { f2 = m.f[x][y];   }
        t = U;
        if (y % 2 != 0 && y % (m.w+1) != 0) { t = E; }
        if (y % 2 == 0 && y % (m.w+1) != 0) { t = W; }
        break;
      case E: case W:
        v1 = m.v[x][y];
        v2 = m.v[x][y+1];
        if (x != 0)     { f1 = m.f[x-1][y]; } 
        if (x != m.h+1) { f2 = m.f[x][y];   }
        t = U;
        if (x % 2 != 0 && x % (m.h+1) != 0) { t = S; }
        if (x % 2 == 0 && x % (m.h+1) != 0) { t = N; }
        break;
    }
  }
  
  void display() {
    stroke(0); noFill();
    switch (g) { 
      case PS: arrow(f1.px,f1.py,f2.px,f2.py); break;
      case NG: arrow(f2.px,f2.py,f1.px,f1.py); break;
    }
    switch (a) {
      case UN: stroke(0); break;
      case MT: stroke(255,64,64); break;
      case VY: stroke(0,128,255); break;
    }
    noFill();
    strokeWeight(4);
    line(v1.px,v1.py,v2.px,v2.py);
    strokeWeight(1);
    String str = str(t);
    switch (t) { 
      case U: str = " "; fill(255);       break;
      case N: str = "N"; fill(255,64,64); break;
      case W: str = "W"; fill( 0,200, 0); break;
      case S: str = "S"; fill(255,128,0); break;
      case E: str = "E"; fill(0,128,255); break;
    }
    if (m.showEdges) {
      if (t != U) {
        stroke(128);
        ellipse(px,py,RAD,RAD);
        strokeWeight(1);
        noStroke(); fill(0);
        textSize(10); textAlign(CENTER, CENTER);
        text(str,px,py);
        if (s) { 
          strokeWeight(2);
          stroke(255,0,0); noFill();
          ellipse(px,py,1.5*RAD,1.5*RAD);
          strokeWeight(1);
        }
      }
    }
  }
  
  void update() {
    if (a != UN) {
      float ext = float(m.maxSize);
      float sft = float(OFFSET);
      int i = min(f1.l,f2.l)-1;
      int j = max(f1.l,f2.l)-1;
      tx = ext+2*sft+i*m.tsc;
      ty = sft+ext-j*m.tsc;
    }
  }
  
  void displayLines() {
    if (a != UN) {
      switch (t) { 
        case U: stroke(255); fill(255);       break;
        case N: stroke(255,64,64); fill(255,64,64); break;
        case W: stroke( 0,200, 0); fill( 0,200, 0); break;
        case S: stroke(255,128,0); fill(255,128,0); break;
        case E: stroke(0,128,255); fill(0,128,255); break;
      }
      if (m.dispTok == U) {
        Face fH, fL;
        float tH, tL;
        if (f1.l > f2.l) { fH = f1; fL = f2; }
        else { fH = f2; fL = f1; }
        tH = fH.tx; tL = fL.ty;
        for (int i = 0; i < 4; i++) {
          if (fH.e[i].a != UN && fH.e[i].tx < tH && 
              fL.tx < fH.e[i].tx) { tH = fH.e[i].tx; }
          if (fL.e[i].a != UN && fL.e[i].ty < tL && 
              fH.ty < fL.e[i].ty) { tL = fL.e[i].ty; }
        }
        strokeWeight(2);
        line(tx,ty,fL.tx,tL);
        line(tx,ty,tH,fH.ty);
        strokeWeight(1);
      } else if (m.dispTok == t) {
        strokeWeight(2);
        line(tx,ty,f1.tx,f1.ty);
        line(tx,ty,f2.tx,f2.ty);
        strokeWeight(1);
      }
    }
  }
  
  void displayToken() {
    if (a != UN) {
      switch (t) { 
        case U: stroke(255); fill(255);       break;
        case N: stroke(255,64,64); fill(255,64,64); break;
        case W: stroke( 0,200, 0); fill( 0,200, 0); break;
        case S: stroke(255,128,0); fill(255,128,0); break;
        case E: stroke(0,128,255); fill(0,128,255); break;
      }
      noStroke(); 
      if (m.dispTok == t || m.dispTok >= U) {
        ellipse(tx,ty,m.tsc/1.5,m.tsc/1.5);
      }
      if (s && (m.dispTok >= U || m.dispTok == t)) { 
        strokeWeight(2);
        stroke(225,0,0); noFill();
        ellipse(tx,ty,m.tsc,m.tsc);
        strokeWeight(1);
      }
    }
  }
  
  int intersect(Edge e2) { 
    // returns not zero if edges intersect 
    // & this adjacent to lowest layer
    int pt = 0; // Does not intersect
    Edge e1 = this;
    if (e1.a != UN && e2.a != UN) {
      if (e1.t == e2.t) {
        if (e1.f1.l < e2.f1.l && e2.f1.l < e1.f2.l && 
            e1.f2.l < e2.f2.l) {  pt = 1; }
        if (e1.f1.l < e2.f2.l && e2.f2.l < e1.f2.l && 
            e1.f2.l < e2.f1.l) {  pt = 2; }
        if (e1.f2.l < e2.f1.l && e2.f1.l < e1.f1.l && 
            e1.f1.l < e2.f2.l) {  pt = 3; }
        if (e1.f2.l < e2.f2.l && e2.f2.l < e1.f1.l && 
            e1.f1.l < e2.f1.l) {  pt = 4; }
      }
    }
    return pt;
  }
  
  void arrow(float x1, float y1, float x2, float y2) {
    stroke(0); noFill();
    line(x1,y1,x2,y2);
    float al = 0.25; // arrow length
    float aw = 0.05; // arrow half width
    noStroke(); fill(0);
    triangle(x2,y2,
      x2-al*(x2-x1)+aw*(y1-y2),y2-al*(y2-y1)+aw*(x2-x1),
      x2-al*(x2-x1)-aw*(y1-y2),y2-al*(y2-y1)-aw*(x2-x1));
  }
}