#ifndef WORLDOBJECTVALIDATION_H
#define WORLDOBJECTVALIDATION_H

#include "worldproperties.h"

#include <QString>

class WorldCellObject;

class WorldObjectValidation
{
public:
    static PropertyList resolvedProperties(PropertyHolder *holder);
    static QString resolvedValue(WorldCellObject *object,
                                 const QString &propertyName);
    static void applyCreationDefaults(WorldCellObject *object);
    static bool requiresUnitRectangle(WorldCellObject *object);
    static bool requiresRectangle(WorldCellObject *object);
    static bool validateSpawnPoint(WorldCellObject *object, QString *reason);
    static bool validateExportObject(WorldCellObject *object, QString *reason);
    static QString describe(WorldCellObject *object);
};

#endif
