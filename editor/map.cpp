#include "map.h"

using namespace std;

Map::Map(QWidget *parent) : QGraphicsScene(parent )
{
  action = MODEDRAW; //add new planets by default
  drawingplanet = false;
  drawingorbit = false;
  selectedimg = NULL;
  newplanet = NULL;
  tileimg = false;
  ecc = 0;
  mass = 0;
  planettype = 0;
  orbitdir = false;
  connect(this, SIGNAL(selectionChanged()), this, SLOT(getSelectedPlanets()));
}

Map::~Map()
{
}

void Map::drawBackground(QPainter * painter, const QRectF & rect )
{
  painter->setBrush(QBrush(Qt::black));
  QRectF rect2=sceneRect();
  painter->setPen(Qt::black);
  painter->drawRect(rect2);
}

void Map::drawForeground (QPainter * painter, const QRectF & rect )
{
  Planet *selectedplanet = NULL;
  QList<QGraphicsItem *> selecteditems = selectedItems();
  if(selecteditems.size()==1)
    selectedplanet = (Planet *) selecteditems.first();

  if(action==MODEDRAW && drawingplanet)
  {
    painter->setPen(Qt::green);
    painter->drawEllipse(planetpos.x()-planetsize,planetpos.y()-planetsize,2*planetsize,2*planetsize);
  }
  else if(action==MODEORBIT && drawingorbit && selectedplanet != NULL)
  {
    painter->setPen(Qt::green);
    painter->drawLine(mousepos.x(),mousepos.y(),selectedplanet->getx(),selectedplanet->gety());
  }

  //do stuff for all the visible planets
  //  QList<QGraphicsItem *> planets = items(rect.toRect());
  QList<QGraphicsItem *> planets = items();
  QListIterator<QGraphicsItem *> iterator(planets);
  while(iterator.hasNext())
  {
    Planet *planet = (Planet *) iterator.next();
    //if(action==MODEORBIT) //be careful!! cant do any casting to planets if theres ellipses about
      drawOrbit(painter,planet);
  }  
}

void Map::drawOrbit(QPainter * painter, Planet * planet)
{
  int px,py,sx,sy;
  double r, sp_unitx, sp_unity, centerx, centery;
  double angle,a,b,c;
  QPoint here, point1, point2;

  //draw the orbit path
  if(!planet->fixed())
  {
    Planet *sun = planet->getSun();
    double orbitecc = planet->getEcc();
       
    px = planet->getx();
    py = planet->gety();
    sx = sun->getx();
    sy = sun->gety();
    r = distance(px,py,sx,sy);

    if(r>0)
    {
      a = r/(1+orbitecc);          //semimajor axis
      c = r - a;                   //linear eccentricity
      b = sqrt(pow(a,2)-pow(c,2)); //semiminor axis
         
      painter->setPen(Qt::red);
      painter->drawLine(px,py,sx,sy); //join the two with a line
      painter->setPen(Qt::yellow);

      painter->save(); //save the transformation matrix
      angle = atan2(sy-py,sx-px)*180/M_PI; //anticlockwise angle between the planet and a horizontal line passing through sun

      //calculate unit vector from sun to planet
      sp_unitx = (px - sx)/r;
      sp_unity = (py - sy)/r;

      //find coordinates of centre of ellipse
      centerx = sx+c*sp_unitx;
      centery = sy+c*sp_unity;

      //change coordinate system so that the ellipse is horizontal and centered at the origin
      painter->translate(centerx,centery);
      painter->rotate(angle);

      painter->drawEllipse(-a,-b,2*a,2*b);

      painter->translate(a,0); //now go to the edge of the ellipse (opposite where the planet is)
         
      //draw arrow indicating direction
      here = QPoint(0,0);
      if(planet->iscw())
      {
        point1 = QPoint(-ARROWWIDTH/2,-ARROWHEIGHT);
        point2 = QPoint(ARROWWIDTH/2,-ARROWHEIGHT);
      }
      else
      {
        point1 = QPoint(-ARROWWIDTH/2,ARROWHEIGHT);
        point2 = QPoint(ARROWWIDTH/2,ARROWHEIGHT);
      }
      painter->drawLine(here,point1);
      painter->drawLine(here,point2);

      painter->restore(); //restore normal coordinate system
    }
  }
}


void Map::setAction(int a)
{
  switch(a)
  {
  case ADDPOS:
    this->action = MODEDRAW;
    break;
  case MODIFYPOS:
    this->action = MODESELECT;
    break;
  case ORBITPOS:
    this->action = MODEORBIT;
    break;
  }
  update();
}

void Map::startPlanet(QPoint pos)
{
  drawingplanet = true;
  planetpos = pos;
}

void Map::resizeTempPlanet(int r)
{
  planetsize = r;
  update(); //redraw the ellipse in foreground
}

void Map::finishPlanet(int r)
{
  drawingplanet = false;
  if(selectedimg != NULL && withinMap(planetpos.x(),planetpos.y(),r))
  {
    Planet *planet = new Planet(planetpos.x(),planetpos.y(),r,mass,planettype,selectedimg,tileimg,NULL,0,false);
    addItem(planet);
    planet->setPos(planetpos.x(),planetpos.y()); 
  }
  update();
}

bool Map::withinMap(int x, int y, int r)
{
  QRectF boundary = sceneRect();
  qreal x1,y1,x2,y2;
  boundary.getCoords(&x1, &y1, &x2, &y2);
  return(x-r>x1 && y-r>y1 && x+r<x2 && y+r<y2);
}

void Map::removePlanet(Planet * p)
{
  removeItem(p);
  delete(p); //free memory  
}

void Map::deleteCurrentPlanet()
{
  Planet *selectedplanet;
  QGraphicsItem *selected;
  Planet *planet;

  QList<QGraphicsItem *> selectedplanets = selectedItems();
  QListIterator<QGraphicsItem *> i(selectedplanets);
  while(i.hasNext())
  {
    selected = i.next();
    selectedplanet = (Planet *) selected;

    //stop things from orbiting this planet
    QList<QGraphicsItem *> planets = this->items();
    QListIterator<QGraphicsItem *> j(planets);
    while(j.hasNext())
    {
      planet = (Planet *) j.next();
      if(planet->getSun() == selectedplanet)
        planet->setOrbit(NULL,0,false);
    }

    removePlanet(selectedplanet);
  }
  update();
}

void Map::deletePlanetOrbit()
{
  Planet *selectedplanet;
  QList<QGraphicsItem *> selectedplanets = selectedItems();
  QListIterator<QGraphicsItem *> i(selectedplanets);
  while(i.hasNext())
  {
    selectedplanet = (Planet *) i.next();
    selectedplanet->setOrbit(NULL,0,false);
    update();
  }
}


void Map::addImage(QString filename)
{
  //create image
  QImage *image = new QImage(filename);
  if(image != NULL)
  {
    //make pink invisible
    QColor *maskcolor = new QColor(MASKRED,MASKGREEN,MASKBLUE);
    QImage mask = image->createMaskFromColor(maskcolor->rgb(), Qt::MaskOutColor); //not sure what to do with this yet
    image ->setAlphaChannel(mask);

    //add to list, emit id
    images.append(image);
    filenames.append(filename);
    emit(createdImage(filename,images.size()-1));
  }
}

void Map::save()
{
}

void Map::setImage(int id)
{
  this->selectedimg = images[id];
}
 
void Map::setRadius(const QString &r)
{
  if(r.toInt()>=MINPLANETSIZE)
  {
    Planet *selectedplanet;
    QList<QGraphicsItem *> selectedplanets = selectedItems();
    QListIterator<QGraphicsItem *> i(selectedplanets);
    while(i.hasNext())
    {
      selectedplanet = (Planet *) i.next();
      selectedplanet->setr(r.toInt());
    }
    update();
  }
}

void Map::setEcc(float e)
{
  this->ecc = e;
}

void Map::setPlanetEcc(float e)
{
  Planet *selectedplanet;
  QList<QGraphicsItem *> selectedplanets = selectedItems();
  QListIterator<QGraphicsItem *> i(selectedplanets);
  while(i.hasNext())
  {
    selectedplanet = (Planet *) i.next();
    selectedplanet->setEcc(e);
  }
  update();
}

void Map::setOrbitDir(bool cw)
{
  this->orbitdir = cw;
}

void Map::setPlanetDir(bool cw)
{
  Planet *selectedplanet;
  QList<QGraphicsItem *> selectedplanets = selectedItems();
  QListIterator<QGraphicsItem *> i(selectedplanets);
  while(i.hasNext())
  {
    selectedplanet = (Planet *) i.next();
    selectedplanet->setDir(cw);
  }
  update();
}

void Map::setMass(int m)
{
  this->mass = m;
}

void Map::setType(int t)
{
  this->planettype = t;
}

void Map::setPlanetType(int t)
{
  Planet *selectedplanet;
  QList<QGraphicsItem *> selectedplanets = selectedItems();
  QListIterator<QGraphicsItem *> i(selectedplanets);
  while(i.hasNext())
  {
    selectedplanet = (Planet *) i.next();
    selectedplanet->setType(t);
  }
}


void Map::setPlanetMass(int m)
{
  Planet *selectedplanet;
  QList<QGraphicsItem *> selectedplanets = selectedItems();
  QListIterator<QGraphicsItem *> i(selectedplanets);
  while(i.hasNext())
  {
    selectedplanet = (Planet *) i.next();
    selectedplanet->setMass(m);
  }
}


void Map::getSelectedPlanets()
{
  QList<QGraphicsItem *> selecteditems = this->selectedItems();
  if(selecteditems.size()==1)
  {
    Planet *planet = (Planet *) selecteditems.first();
    emit(planetSelected(planet));
  }
}

float Map::getEcc()
{
  return this->ecc;
}

bool Map::getOrbitDir()
{
  return this->orbitdir;
}

int Map::getAction()
{
  return action;
}

void Map::startOrbit()
{
  drawingorbit = true;
  update();
}

void Map::finishOrbit()
{
  drawingorbit = false;

  QList<QGraphicsItem *> selecteditems = selectedItems();
  if(selecteditems.size()==1)
  {
    Planet *planet1 = (Planet *) selecteditems.first();
    Planet *planet2 = (Planet *) itemAt(mousepos);
    if(planet1 != NULL && planet2 !=NULL && planet1 != planet2) //is there another planet here?
      planet1->setOrbit(planet2,ecc,orbitdir); //create orbit
  }
  update();
}

void Map::resizeOrbit(QPoint pos)
{
  mousepos = pos;
  update();
}

QList<QString> Map::getFilenames()
{
  return filenames;
}

QString Map::lookupFilename(QImage *img)
{
  int i;
  if((i=images.indexOf(img))>-1)
  {
    return filenames[i];
  }
  else return QString();
}
