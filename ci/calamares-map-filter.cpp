/*
 * KaadzOS Calamares locale-map filter.
 *
 * Calamares' locale module draws its world map from embedded QRC images
 * (:/images/bg.png, pin.png and timezone_*.png). Those images are blue, green
 * and red and there is no configuration option to recolour or hide the map, so
 * the AMOLED installer is the last place with a blue-tinted surface.
 *
 * This small LD_PRELOAD library interposes the QImage file constructors, which
 * are the only way the locale module loads those resources. It converts the
 * map to neutral greys, darkens the ocean to true black and makes the selected
 * timezone a quiet grey band. Alpha is preserved exactly: TimeZoneWidget uses
 * zone.pixel(pos) != 0 for hit-testing, so transparent pixels must stay 0.
 *
 * The library is built against trixie's Qt6 in the CI build container and is
 * loaded only by kaadzos-install, never by the installed system.
 */

#include <QImage>
#include <QString>
#include <QtGlobal>

#include <dlfcn.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>

namespace
{

using CharCtor = void (*)(QImage*, const char*, const char*);
using StringCtor = void (*)(QImage*, const QString*, const char*);

thread_local bool g_inHook = false;

CharCtor resolveChar(const char* primary, const char* fallback)
{
    CharCtor fn = reinterpret_cast<CharCtor>(dlsym(RTLD_NEXT, primary));
    if (!fn)
    {
        fn = reinterpret_cast<CharCtor>(dlsym(RTLD_NEXT, fallback));
    }
    return fn;
}

StringCtor resolveString(const char* primary, const char* fallback)
{
    StringCtor fn = reinterpret_cast<StringCtor>(dlsym(RTLD_NEXT, primary));
    if (!fn)
    {
        fn = reinterpret_cast<StringCtor>(dlsym(RTLD_NEXT, fallback));
    }
    return fn;
}

bool isLocaleMap(const QString& name)
{
    return name.startsWith(QLatin1String(":/images/"))
        && (name.endsWith(QLatin1String("/bg.png"))
            || name.endsWith(QLatin1String("/pin.png"))
            || name.contains(QLatin1String("/timezone_")));
}

bool isLocaleMap(const char* name)
{
    return name && std::strncmp(name, ":/images/", 9) == 0
        && isLocaleMap(QString::fromLatin1(name));
}

void makeAmoled(QImage& image, const QString& path)
{
    if (image.isNull())
    {
        return;
    }

    const bool pin = path.endsWith(QLatin1String("/pin.png"));
    const bool zone = path.contains(QLatin1String("/timezone_"));

    const QImage source = image.convertToFormat(QImage::Format_ARGB32);
    QImage out(source.size(), QImage::Format_ARGB32);
    out.fill(Qt::transparent);

    for (int y = 0; y < source.height(); ++y)
    {
        const QRgb* in = reinterpret_cast<const QRgb*>(source.constScanLine(y));
        QRgb* dst = reinterpret_cast<QRgb*>(out.scanLine(y));
        for (int x = 0; x < source.width(); ++x)
        {
            const QRgb pixel = in[x];
            const int alpha = qAlpha(pixel);
            if (alpha == 0)
            {
                // Keep fully-transparent pixels exactly zero for timezone
                // hit-testing, even if the source carried RGB under alpha 0.
                dst[x] = 0;
                continue;
            }

            const int r = qRed(pixel);
            const int g = qGreen(pixel);
            const int b = qBlue(pixel);
            const int lum = (r * 299 + g * 587 + b * 114) / 1000;
            int v;

            if (pin)
            {
                // The pin is red with a dark outline and a white centre. Turn
                // the red body into the white accent and leave the outline.
                v = (r > g + 20 && r > b + 20) ? 235 : qBound(0, lum, 255);
            }
            else if (zone)
            {
                // The selected zone is a green fill with a translucent blue
                // edge. A single light grey keeps the band visible on the dark
                // map; preserving alpha keeps the edge subtle.
                v = 90;
            }
            else if (b > r + 8)
            {
                // Blue ocean: true black.
                v = 0;
            }
            else
            {
                // White land and pale coastlines: quiet dark grey.
                v = 10 + (lum * 64) / 255;
            }

            dst[x] = qRgba(v, v, v, alpha);
        }
    }

    image = out;
}

}  // namespace

extern "C" void kaadzos_qimage_c1_char(QImage* self, const char* fileName, const char* format)
    __asm__("_ZN6QImageC1EPKcS1_");
extern "C" void kaadzos_qimage_c1_char(QImage* self, const char* fileName, const char* format)
{
    static CharCtor real = resolveChar(
        "_ZN6QImageC1EPKcS1_", "_ZN6QImageC2EPKcS1_");
    if (!real)
    {
        std::fprintf(stderr, "kaadzos-map-filter: QImage(char*) constructor not found\n");
        std::abort();
    }
    if (g_inHook)
    {
        real(self, fileName, format);
        return;
    }
    g_inHook = true;
    real(self, fileName, format);
    g_inHook = false;
    if (isLocaleMap(fileName))
    {
        makeAmoled(*self, QString::fromLatin1(fileName));
    }
}

extern "C" void kaadzos_qimage_c2_char(QImage* self, const char* fileName, const char* format)
    __asm__("_ZN6QImageC2EPKcS1_");
extern "C" void kaadzos_qimage_c2_char(QImage* self, const char* fileName, const char* format)
{
    static CharCtor real = resolveChar(
        "_ZN6QImageC2EPKcS1_", "_ZN6QImageC1EPKcS1_");
    if (!real)
    {
        std::fprintf(stderr, "kaadzos-map-filter: QImage(char*) base constructor not found\n");
        std::abort();
    }
    if (g_inHook)
    {
        real(self, fileName, format);
        return;
    }
    g_inHook = true;
    real(self, fileName, format);
    g_inHook = false;
    if (isLocaleMap(fileName))
    {
        makeAmoled(*self, QString::fromLatin1(fileName));
    }
}

extern "C" void kaadzos_qimage_c1_string(QImage* self, const QString* fileName, const char* format)
    __asm__("_ZN6QImageC1ERK7QStringPKc");
extern "C" void kaadzos_qimage_c1_string(QImage* self, const QString* fileName, const char* format)
{
    static StringCtor real = resolveString(
        "_ZN6QImageC1ERK7QStringPKc", "_ZN6QImageC2ERK7QStringPKc");
    if (!real)
    {
        std::fprintf(stderr, "kaadzos-map-filter: QImage(QString) constructor not found\n");
        std::abort();
    }
    if (g_inHook)
    {
        real(self, fileName, format);
        return;
    }
    g_inHook = true;
    real(self, fileName, format);
    g_inHook = false;
    if (fileName && isLocaleMap(*fileName))
    {
        makeAmoled(*self, *fileName);
    }
}

extern "C" void kaadzos_qimage_c2_string(QImage* self, const QString* fileName, const char* format)
    __asm__("_ZN6QImageC2ERK7QStringPKc");
extern "C" void kaadzos_qimage_c2_string(QImage* self, const QString* fileName, const char* format)
{
    static StringCtor real = resolveString(
        "_ZN6QImageC2ERK7QStringPKc", "_ZN6QImageC1ERK7QStringPKc");
    if (!real)
    {
        std::fprintf(stderr, "kaadzos-map-filter: QImage(QString) base constructor not found\n");
        std::abort();
    }
    if (g_inHook)
    {
        real(self, fileName, format);
        return;
    }
    g_inHook = true;
    real(self, fileName, format);
    g_inHook = false;
    if (fileName && isLocaleMap(*fileName))
    {
        makeAmoled(*self, *fileName);
    }
}
