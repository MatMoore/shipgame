#ifndef PLANET_H
#define PLANET_H

#include <string>
#include <QPoint>
#include <cmath>
#include <QImage>
#include <QMouseEvent>
#include <QPixmap>
#include <QPainter>
#include <constants.h>
#include <QWidget>
#include <iostream>
#include "constants.h"
#include <QGraphicsPixmapItem>

#define PLANET 0
#define SUN 1
#define SPACESTATION 2

#define MOUSEREACH 10

class Planet : public QGraphicsPixmapItem{
  //  Q_OBJECT //macro for all the slots and signals stuff

 protected:
  //  int x;
  //  int y;
  int r;
  QImage *image;
  bool istiled;
  int m; //mass
  int behaviour;
  Planet *sun; //what it orbits
  double ecc; //eccentricity of orbit
  bool cw; //direction of orbit
  //  int action;

 public :
  Planet(int x, int y, int r, int m, int type, QImage *img, bool istiled, Planet *sun, double ecc, bool cw);
  //Planet(const Planet &other);
  //Planet(QPoint point, QObject *parent=0);
  //bool operator==(const QPoint &point) const;
  //bool operator==(const Planet &other);
  //Planet operator=(const Planet &other);
  int getx();
  int gety();
  int getr();
  int getm();
  int getType();
  bool iscw();
  QImage * getimg();
  void setr(int r);
  bool isimgtiled();
  //void setPosition(QPoint q);
  void setOrbit(Planet *sun, double ecc, bool cw);
  bool fixed();
  Planet * getSun();
  double getEcc();
  void setEcc(double ecc);
  void setDir(bool);
  void setMass(int m);
  void setType(int t);
  //void mousePressEvent(QMouseEvent * e);
  //void mouseMoveEvent(QMouseEvent * e);
  //void mouseReleaseEvent(QMouseEvent * e);
  //void paintEvent(QPaintEvent * event);
  /*
  public slots:
  void setClickAction(int action);
  
  signals:
  void selectPlanet(Planet *planet, QPoint p);
  void mousePressed(Planet *planet, QPoint p);
  void mouseMoved(Planet *planet, QPoint p);
  void mouseReleased(Planet *planet, QPoint p);
  */
};
#endif
