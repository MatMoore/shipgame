#include "mywidget.h"

MyWidget::MyWidget( QWidget *parent ) : QWidget( parent )
{
  /* NO NO NO NO
  //clickable buttons
  QPushButton *addPlanet = new QPushButton( "Add planets");
  QPushButton *addSun = new QPushButton( "Add suns");
  QPushButton *modify = new QPushButton("Modify");
  QPushButton *orbit = new QPushButton("Add orbit");
  */
  QTabWidget *menuThingy = new QTabWidget(); //ahh, much better

  //create menus
  AddMenu *addMenu = new AddMenu;
  ModifyMenu *modifyMenu = new ModifyMenu;
  OrbitMenu *orbitMenu = new OrbitMenu;

  //                      position   widget      label
  menuThingy -> insertTab(ADDPOS,    addMenu,    QString("Add &planet"));
  menuThingy -> insertTab(MODIFYPOS, modifyMenu, QString("&Modify planet"));
  menuThingy -> insertTab(ORBITPOS,  orbitMenu,  QString("Set &orbit"));

  //  scene = new QGraphicsScene; //this is the actual map which holds all the planets
  universe = new Map;
  universe->setSceneRect(0, 0, DEFAULTMAPSIZE, DEFAULTMAPSIZE); //size of the map

  // map controls
  QPushButton *zoomIn = new QPushButton("Zoom in");
  QPushButton *zoomOut = new QPushButton("Zoom out");
  QPushButton *normal = new QPushButton("Normal size");
  QLineEdit *mapSize = new QLineEdit;
  QValidator *intvalidator = new QIntValidator(MINMAPSIZE, MAXMAPSIZE, this);
  mapSize->setValidator(intvalidator);
  mapSize -> insert("10000");
  QLabel *mapSizeLabel = new QLabel("Map size");

  //make scrollable map
  MapView *view1 = new MapView(universe); //this is a scrollable box which shows a certain view of the scene
  MiniMapView *view2 = new MiniMapView(universe, view1); //another view is zoomed out and can be used to alter view1

  //add options for each
  QGridLayout *mapOptions = new QGridLayout;
  //  mapOptions -> addWidget(view2, 0, 0, 2, 1);
  mapOptions -> addWidget(mapSizeLabel, 0, 0);
  mapOptions -> addWidget(mapSize, 0, 1);
  mapOptions -> addWidget(zoomIn, 1, 0, 1,2);
  mapOptions -> addWidget(normal, 2, 0, 1, 2);
  mapOptions -> addWidget(zoomOut, 3, 0, 1, 2);

  /* QGridLayout *mapOptions2 = new QGridLayout;
  mapOptions2 -> addWidget(view2, 0, 0, 1, 4);
  mapOptions2 -> addWidget(zoomIn2, 1, 2);
  mapOptions2 -> addWidget(zoomOut2, 1, 3);
  */

  //now position everything nicely
  QGridLayout *gridLayout = new QGridLayout(this);
  gridLayout -> addWidget(view1, 0, 0, 1, 2);
  gridLayout -> addWidget(view2, 1, 0);
  gridLayout -> addLayout(mapOptions, 1, 1);
  gridLayout -> addWidget(menuThingy, 0, 2, 2, 1); //span 2 both rows

  gridLayout -> setColumnStretch(0, 4); //make it stretchable
  gridLayout -> setColumnStretch(1, 2);
  gridLayout -> setColumnStretch(2, 3); //this takes up half as much as the map
  gridLayout -> setRowStretch(0,1);
  gridLayout -> setRowStretch(1,1);


  //show everything in the bottom one (this is a bit rubbish, cause it doesnt update when the box gets resized)
  // QRectF rect = view2 -> sceneRect();
  //view2->fitInView(rect, Qt::KeepAspectRatio);

  /*--------------------------------
    lots of signals and slots! eek!
  ---------------------------------*/

  //the map widget behaves differently in each mode, so it needs to be told whenever the current menu tab changes
  connect(menuThingy, SIGNAL(currentChanged(int)), universe, SLOT(setAction(int)));

  //when a file is opened, store the image in the map object
  connect(addMenu, SIGNAL(newImage(QString)), universe, SLOT(addImage(QString)));

  //if an image is created successfully then add an entry to the drop down list
  connect(universe, SIGNAL(createdImage(QString,int)), addMenu, SLOT(addImage(QString,int)));

  //...then update the currently selected image in map class (what new planets are drawn with)
  connect(addMenu, SIGNAL(changedImage(int)), universe, SLOT(setImage(int)));

  //inform the menus when a planet is selected
  connect(universe, SIGNAL(planetSelected(Planet *)), modifyMenu, SLOT(getPlanetDetails(Planet *)));

  //this box has an integer validator, so its not possible to enter non-valid input, so ive connected it directly to the map function. this is probably bad
  connect(modifyMenu->setRadius, SIGNAL(textEdited(const QString &)), universe, SLOT(setRadius(const QString &)));

  //the eccentricity box accepts floats, so it needs to be checked first. changedEcc is only emitted when the input is valid
  connect(modifyMenu, SIGNAL(changedEcc(float)), universe, SLOT(setPlanetEcc(float)));
  connect(orbitMenu, SIGNAL(changedEcc(float)), universe, SLOT(setEcc(float)));

  //change the direction that planets orbit in (clockwise by default)
  connect(orbitMenu, SIGNAL(changedDirection(bool)), universe, SLOT(setOrbitDir(bool)));
  connect(modifyMenu, SIGNAL(changedDirection(bool)), universe, SLOT(setPlanetDir(bool)));

  //mass of the planet
  connect(addMenu, SIGNAL(changedMass(int)), universe, SLOT(setMass(int)));
  connect(modifyMenu, SIGNAL(changedMass(int)), universe, SLOT(setPlanetMass(int)));

  //type of the planet
  connect(addMenu, SIGNAL(newType(int)), universe, SLOT(setType(int)));
  connect(modifyMenu, SIGNAL(newType(int)), universe, SLOT(setPlanetType(int)));

  //delete things
  connect(modifyMenu, SIGNAL(deletePlanet()), universe, SLOT(deleteCurrentPlanet()));
  connect(modifyMenu, SIGNAL(deleteOrbit()), universe, SLOT(deletePlanetOrbit()));
  
  //change map size
  connect(mapSize, SIGNAL(textEdited(const QString &)), this, SLOT(changeMapSize(const QString &)));

  //zooming
  connect(zoomIn, SIGNAL(clicked()), view1, SLOT(zoomIn()));
  connect(zoomOut, SIGNAL(clicked()), view1, SLOT(zoomOut()));
  connect(normal, SIGNAL(clicked()), view1, SLOT(normalSize()));
}

void MyWidget::changeMapSize(const QString &str)
{
  int size = str.toInt();
  if(size<=MAXMAPSIZE && size>=MINMAPSIZE)
    universe->setSceneRect(0, 0, size, size);

  //QRectF rect = view2 -> sceneRect();
  //view2->fitInView(rect, Qt::KeepAspectRatio);
}

void MyWidget::saveDialog()
{
  QFileDialog::Options options;
  QString filename = QFileDialog::getSaveFileName(this,tr("QFileDialog::getSaveFileName()"),QDir::homePath(),tr("All Files (*);;XML (*.xml)"));
  save(filename);
}

void MyWidget::save(QString outfile)
{
  QFile file(outfile);
  if (!file.open(QIODevice::WriteOnly | QIODevice::Text))
    return;

  QTextStream out(&file);

  //get map details
  QRectF maprect = universe->sceneRect();
  qreal x,y,width,height;
  maprect.getRect(&x,&y,&width,&height);
  out << "<map width=\"" << width  << "\" ";
  out << "height=\"" << height  << "\">\n";

  //get image details
  QList<QString> images = universe->getFilenames();
  QListIterator<QString> iterator(images);
  while(iterator.hasNext())
  {
    QString image = iterator.next();
  }  

  //get planet details
  QList<QGraphicsItem *> planets = universe->items();
  QListIterator<QGraphicsItem *> iterator2(planets);
  while(iterator2.hasNext())
  {
    QGraphicsItem *item = iterator2.next();
    Planet *planet = (Planet *) item;
    out << "\n<object ";
    out << "id=\"" << planets.indexOf(item) << "\" ";
    out << "x=\"" << planet->getx()-width/2 << "\" ";
    out << "y=\"" << planet->gety()-height/2 << "\" ";
    out << "radius=\"" << planet->getr() << "\" ";
    out << "mass=\"" << planet->getm() << "\" ";

    QString type;
    switch(planet->getType())
    {
      case STARPOS:
        type="star";
        break;
      case SSPOS:
        type="space station";
        break;
      default: 
        type="planet";
    }

    out << "type=\"" << type << "\">\n";
    QImage *image = planet->getimg();
    QString filename = universe->lookupFilename(image);
    out << "\t<image ";
    if(planet->isimgtiled() or 1) //The map editor doesnt support tiling yet, but this is what we want atm so force this option
      out << "style=\"tiled\">\n";
    else
      out << "style=\"stretched\">";
    out << filename << "</image>\n";
    if(!planet->fixed())
    {
      Planet *sun = planet->getSun();
      out << "\t<orbit object=\"" << planets.indexOf(sun) <<"\" ";
      out << "eccentricity=\"" << planet->getEcc()<<"\" ";
      if(planet->iscw())
        out << "direction=\"clockwise\" />\n";
      else
        out << "direction=\"anticlockwise\" />\n";
    }
    out << "</object>\n";
  }  

  out << "\n</map>";
  file.flush();
}

void MyWidget::selectAll()
{
  QList<QGraphicsItem *> planets = universe->items();
  QListIterator<QGraphicsItem *> iterator2(planets);
  while(iterator2.hasNext())
  {
    QGraphicsItem *item = iterator2.next();
    item->setSelected(true);
  }
}

void MyWidget::newMap()
{
  QList<QGraphicsItem *> planets = universe->items();
  QListIterator<QGraphicsItem *> iterator2(planets);
  while(iterator2.hasNext())
  {
    QGraphicsItem *item = iterator2.next();
    Planet *planet = (Planet *) item;
    universe->removePlanet(planet); //this is probably a very silly way of doing it
  }
}
