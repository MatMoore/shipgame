#ifndef MYWIDGET_H
#define MYWIDGET_H

#include <qwidget.h>
#include "planet.h"
#include "map.h"
#include <QPushButton>
#include <QLineEdit>
#include <QGridLayout>
#include <QScrollArea>
#include <QFileDialog>
#include <QComboBox>
#include <iostream>
#include <fstream>
#include "addMenu.h"
#include "modifyMenu.h"
#include "orbitMenu.h"
#include "constants.h"
#include <QTabWidget>
#include "mapview.h"
#include "minimapview.h"
#include <QTextStream>

using namespace std;

class MyWidget : public QWidget
{
  Q_OBJECT //macro for all the slots and signals stuff

private:
  Map *universe; //the map. contains all the planets
  //MapView *view2; //minimap type thing

public:
  MyWidget( QWidget *parent=0);

public slots:
  void changeMapSize(const QString &str);
  void save(QString outfile);
  void saveDialog();
  void newMap();
  void selectAll();
};

#endif
