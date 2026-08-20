#include "worldobjectvalidation.h"

#include "world.h"
#include "worldcell.h"

#include <QCoreApplication>
#include <QtMath>

namespace {

void resolveProperties(PropertyHolder *holder, PropertyList &result)
{
    for (PropertyTemplate *propertyTemplate : holder->templates())
        resolveProperties(propertyTemplate, result);
    for (Property *property : holder->properties()) {
        result.removeAll(property->mDefinition);
        result += property;
    }
}

bool isBoolean(const QString &value)
{
    return value.compare(QLatin1String("true"), Qt::CaseInsensitive) == 0
            || value.compare(QLatin1String("false"), Qt::CaseInsensitive) == 0;
}

bool isNumber(const QString &value)
{
    bool ok = false;
    value.toDouble(&ok);
    return ok;
}

bool isIntegral(qreal value)
{
    return qFuzzyIsNull(value - qRound64(value));
}

bool hasIntegralPosition(WorldCellObject *object)
{
    return isIntegral(object->x()) && isIntegral(object->y());
}

QString typeName(WorldCellObject *object)
{
    return object && object->type() ? object->type()->name() : QString();
}

void attachTemplate(WorldCellObject *object, const QString &name)
{
    World *world = object->cell()->world();
    PropertyTemplate *propertyTemplate = world->propertyTemplate(name);
    if (propertyTemplate && !object->usesTemplate(propertyTemplate)
            && object->canAddTemplate(propertyTemplate)) {
        object->addTemplate(object->templates().size(), propertyTemplate);
    }
}

void addDefaultProperty(WorldCellObject *object, const QString &name,
                        const QString &value)
{
    PropertyDef *definition = object->cell()->world()->propertyDefinition(name);
    if (definition && !object->properties().find(definition)) {
        object->addProperty(object->properties().size(),
                            new Property(definition, value));
    }
}

QString translated(const char *text)
{
    return QCoreApplication::translate("WorldObjectValidation", text);
}

}

PropertyList WorldObjectValidation::resolvedProperties(PropertyHolder *holder)
{
    PropertyList result;
    if (holder)
        resolveProperties(holder, result);
    return result;
}

QString WorldObjectValidation::resolvedValue(WorldCellObject *object,
                                             const QString &propertyName)
{
    if (!object || !object->cell())
        return QString();
    PropertyDef *definition =
            object->cell()->world()->propertyDefinition(propertyName);
    if (!definition)
        return QString();
    Property *property = resolvedProperties(object).find(definition);
    return property ? property->mValue.trimmed() : QString();
}

void WorldObjectValidation::applyCreationDefaults(WorldCellObject *object)
{
    if (!object || !object->cell())
        return;

    const QString type = typeName(object);
    if (type == QLatin1String("SpawnPoint")) {
        attachTemplate(object, type);
        addDefaultProperty(object, QLatin1String("Professions"),
                           QLatin1String("unemployed"));
    } else if (type == QLatin1String("WaterFlow")) {
        attachTemplate(object, type);
        addDefaultProperty(object, QLatin1String("WaterDirection"),
                           QLatin1String("0"));
        addDefaultProperty(object, QLatin1String("WaterSpeed"),
                           QLatin1String("0.0"));
    } else if (type == QLatin1String("WaterZone")) {
        attachTemplate(object, type);
        addDefaultProperty(object, QLatin1String("WaterGround"),
                           QLatin1String("false"));
        addDefaultProperty(object, QLatin1String("WaterShore"),
                           QLatin1String("true"));
    } else if (type == QLatin1String("RoomTone")) {
        attachTemplate(object, type);
        addDefaultProperty(object, QLatin1String("RoomTone"),
                           QLatin1String("Generic"));
        addDefaultProperty(object, QLatin1String("EntireBuilding"),
                           QLatin1String("false"));
    }

    if (requiresUnitRectangle(object)) {
        object->setGeometryType(ObjectGeometryType::INVALID);
        object->setWidth(1);
        object->setHeight(1);
    }
}

bool WorldObjectValidation::requiresUnitRectangle(WorldCellObject *object)
{
    const QString type = typeName(object);
    return type == QLatin1String("SpawnPoint")
            || type == QLatin1String("WaterFlow")
            || type == QLatin1String("RoomTone");
}

bool WorldObjectValidation::requiresRectangle(WorldCellObject *object)
{
    const QString type = typeName(object);
    return requiresUnitRectangle(object)
            || type == QLatin1String("WaterZone");
}

bool WorldObjectValidation::validateSpawnPoint(WorldCellObject *object,
                                               QString *reason)
{
    if (!object || !object->cell() || !object->type()
            || !object->isSpawnPoint()) {
        if (reason)
            *reason = translated("the record is not a valid SpawnPoint object");
        return false;
    }
    if (!object->isRectangle() || object->width() != 1
            || object->height() != 1) {
        if (reason)
            *reason = translated("SpawnPoint must be a 1 x 1 rectangle");
        return false;
    }
    if (!hasIntegralPosition(object)) {
        if (reason)
            *reason = translated("SpawnPoint position must use whole map-square coordinates");
        return false;
    }

    const QString professions = resolvedValue(
                object, QLatin1String("Professions"));
    if (professions.isEmpty()) {
        if (reason)
            *reason = translated("SpawnPoint must define at least one profession");
        return false;
    }
    const QStringList values = professions.split(
                QLatin1Char(','), Qt::SkipEmptyParts);
    bool hasProfession = false;
    for (const QString &value : values) {
        const QString profession = value.trimmed();
        if (profession.isEmpty())
            continue;
        hasProfession = true;
        if (profession.compare(
                    QLatin1String("all"), Qt::CaseInsensitive) == 0) {
            if (reason)
                *reason = translated("SpawnPoint profession 'all' is not supported. Select one or more explicit professions");
            return false;
        }
    }
    if (!hasProfession) {
        if (reason)
            *reason = translated("SpawnPoint must define at least one profession");
        return false;
    }
    return true;
}

bool WorldObjectValidation::validateExportObject(WorldCellObject *object,
                                                 QString *reason)
{
    if (!object || !object->cell() || !object->type()) {
        if (reason)
            *reason = translated("the object has no valid cell or type");
        return false;
    }

    const QString type = typeName(object);
    if (type == QLatin1String("SpawnPoint"))
        return validateSpawnPoint(object, reason);

    if (type == QLatin1String("WaterFlow")) {
        if (!object->isRectangle() || object->width() != 1
                || object->height() != 1) {
            if (reason)
                *reason = translated("WaterFlow must be a 1 x 1 rectangle");
            return false;
        }
        if (!hasIntegralPosition(object)) {
            if (reason)
                *reason = translated("WaterFlow position must use whole map-square coordinates");
            return false;
        }
        if (!isNumber(resolvedValue(object,
                                    QLatin1String("WaterDirection")))
                || !isNumber(resolvedValue(object,
                                           QLatin1String("WaterSpeed")))) {
            if (reason)
                *reason = translated("WaterFlow must define numeric WaterDirection and WaterSpeed properties");
            return false;
        }
    } else if (type == QLatin1String("WaterZone")) {
        if (!object->isRectangle() || object->width() < 1
                || object->height() < 1
                || !isIntegral(object->width())
                || !isIntegral(object->height())
                || !hasIntegralPosition(object)) {
            if (reason)
                *reason = translated("WaterZone must be a non-empty rectangle aligned to whole map squares");
            return false;
        }
        if (!isBoolean(resolvedValue(object,
                                     QLatin1String("WaterGround")))
                || !isBoolean(resolvedValue(object,
                                            QLatin1String("WaterShore")))) {
            if (reason)
                *reason = translated("WaterZone must define boolean WaterGround and WaterShore properties");
            return false;
        }
    } else if (type == QLatin1String("RoomTone")) {
        if (!object->isRectangle() || object->width() != 1
                || object->height() != 1) {
            if (reason)
                *reason = translated("RoomTone must be a 1 x 1 rectangle");
            return false;
        }
        if (!hasIntegralPosition(object)) {
            if (reason)
                *reason = translated("RoomTone position must use whole map-square coordinates");
            return false;
        }
        if (resolvedValue(object, QLatin1String("RoomTone")).isEmpty()
                || !isBoolean(resolvedValue(
                                  object,
                                  QLatin1String("EntireBuilding")))) {
            if (reason)
                *reason = translated("RoomTone must define RoomTone and a boolean EntireBuilding property");
            return false;
        }
    }
    return true;
}

QString WorldObjectValidation::describe(WorldCellObject *object)
{
    if (!object || !object->cell())
        return translated("Unknown object");
    const QPointF position = object->absoluteWorldPosition();
    const QString type = typeName(object).isEmpty()
            ? translated("Object") : typeName(object);
    return QString::fromLatin1("%1 at posX %2, posY %3, posZ %4")
            .arg(type)
            .arg(qRound64(position.x()))
            .arg(qRound64(position.y()))
            .arg(object->level());
}
