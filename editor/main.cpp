#include <QApplication>
#include "mainwindow.h"

int main(int argc, char *argv[])
{
     QApplication app(argc, argv);
     MainWindow mapeditor; //the main window
     mapeditor.show();
     return app.exec();
}
