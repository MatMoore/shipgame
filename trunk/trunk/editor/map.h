#ifndef MAP_H
#define MAP_H

#include "constants.h"
#include <QWidget>
#include "planet.h"
#include <string>
#include <qpushbutton.h>
#include <QFont>
#include <QPainter>
#include <QMouseEvent>
#include <iostream>
#include <cmath>
#include <QList>
#include <QListIterator>
#include <QImage>
#include <QtAlgorithms>
#include <QGraphicsView>
#include <QRubberBand>

class Map : public QGraphicsScene
{
  Q_OBJECT //macro for all the slots and signals stuff

public:
  Map(QWidget *parent=0);
  virtual ~Map();
  int distance(int x1, int y1, int x2, int y2) {return(sqrt(pow((double)(x1-x2),2)+pow((double)(y1-y2),2)));}
  float getEcc();
  bool getOrbitDir();
  int getAction();
  QList<QString> getFilenames();
  QString lookupFilename(QImage *img);
  
public slots:
  void save(); //save map data to file
  void setImage(int id);
  void addImage(QString filename);
  void setAction(int a);
  void setRadius(const QString &r);
  void setEcc(float e);
  void setPlanetEcc(float e);
  void setOrbitDir(bool cw);
  void setPlanetDir(bool cw);
  void setMass(int m);
  void setPlanetMass(int m);
  void setType(int);
  void setPlanetType(int);
  void deleteCurrentPlanet();
  void deletePlanetOrbit();
  void startPlanet(QPoint pos);
  void resizeTempPlanet(int r);
  void finishPlanet(int r);
  void removePlanet(Planet * p);
  void getSelectedPlanets();
  void startOrbit();
  void finishOrbit();
  void resizeOrbit(QPoint pos);

signals:
  void createdImage(QString filename, int id);
  void planetSelected(Planet *p);
  void newAction(int);

protected:
  QList<QImage *> images; //list of images to use as planets
  QList<QString> filenames; //filenames of the images
  QImage * selectedimg;
  QGraphicsEllipseItem * newplanet;
  int action; //what action to do (add/remove etc)
  int tileimg; //whether image is tiled or not
  double ecc; //eccentricity of orbit
  bool orbitdir; //true = clockwise, false = anticlockwise
  QPoint clickpoint; //the position the mouse was when it was clicked
  QPoint mousepos; //where it is now
  bool drawingplanet; //true if a planet is being drawn
  bool drawingorbit;
  int planetsize;
  QPoint planetpos;
  int mass;
  int planettype;
  void drawForeground (QPainter * painter, const QRectF & rect );
  void drawBackground(QPainter * painter, const QRectF & rect );
  void drawOrbit(QPainter * painter, Planet * planet);
  void mousePressEvent(QMouseEvent * e);
  void mouseReleaseEvent(QMouseEvent * e);
  void mouseMoveEvent(QMouseEvent * e);
  bool withinMap(int x, int y, int r); //is a planet of radius r at pos x,y within the map
};

#endif
