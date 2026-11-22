import plistlib
import sys
from pathlib import Path

app = Path(sys.argv[1])
bundle = 'org.artcraftquicklook.local'
# The project types: UTI, extensions and conformance. SolidCraft, FilmCraft, MaterialCraft and
# EffectCraft repeat the declaration their own app exports.
formats = {
    'ai.storyteller.figcraft.document': (['figcraft'], ['public.content', 'public.data']),
    'ai.storyteller.designcraft.document': (['designcraft'], ['public.content', 'public.data']),
    'ai.storyteller.vectorcraft.document': (['vectorcraft'], ['public.content', 'public.data']),
    'ai.storyteller.texturecraft.project': (['tcraft'], ['public.content', 'public.data']),
    'ai.storyteller.photocraft.document': (['pcraft'], ['public.data', 'public.image']),
    'io.tangencylabs.solidcraft.design': (['sc', 'solidcraft'], ['public.data', 'public.content']),
    'ai.storyteller.filmcraft.project': (['fcproj'], ['public.data', 'public.json']),
    'ai.storyteller.materialcraft.package': (['mcraft'], ['public.data', 'public.content']),
    'ai.storyteller.effectcraft.document': (['ecproj', 'ecprojx'], ['public.data', 'public.content']),
}
# Types macOS declares itself, so they are only listed in the extensions.
system_types = ['com.adobe.photoshop-image', 'public.svg-image']
def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(plistlib.dumps(data))

def info(name, kind, identifier):
    return dict(CFBundleExecutable=name, CFBundleIdentifier=identifier, CFBundleName=name,
                CFBundleDisplayName='ArtCraft Quick Look', CFBundlePackageType=kind,
                CFBundleVersion='10', CFBundleShortVersionString='0.3.0',
                CFBundleInfoDictionaryVersion='6.0', LSMinimumSystemVersion='13.0',
                CFBundleDevelopmentRegion='it', CFBundleSupportedPlatforms=['MacOSX'])

host = info('ArtCraftQuickLook', 'APPL', bundle)
host['CFBundleIconFile'] = 'ArtCraftQuickLook.icns'
host['UTImportedTypeDeclarations'] = [
    dict(UTTypeIdentifier=uti, UTTypeDescription=f'{extensions[0]} document',
         UTTypeTagSpecification={'public.filename-extension': extensions}, UTTypeConformsTo=conforms)
    for uti, (extensions, conforms) in formats.items()
]
write(app/'Contents/Info.plist', host)
for name, point in [('Preview','preview'),('Thumbnail','thumbnail')]:
    p = info(name, 'XPC!', bundle+'.'+point)
    attrs = dict(QLSupportedContentTypes=[*formats, *system_types])
    if name == 'Preview':
        attrs.update(QLIsDataBasedPreview=True, QLSupportsSearchableItems=False)
    else:
        attrs['QLThumbnailMinimumDimension'] = 0
    p['NSExtension'] = dict(NSExtensionPointIdentifier='com.apple.quicklook.'+point,
                          NSExtensionPrincipalClass=f'{name}.{name}Provider',
                          NSExtensionAttributes=attrs)
    write(app/f'Contents/PlugIns/{name}.appex/Contents/Info.plist', p)
    service = info('CraftRender', 'XPC!', bundle + '.' + point + '.render')
    service['XPCService'] = {'ServiceType': 'Application'}
    write(app/f'Contents/PlugIns/{name}.appex/Contents/XPCServices/CraftRender.xpc/Contents/Info.plist', service)
write(app.parent/'Service.entitlements', {'com.apple.security.app-sandbox': True})
write(app.parent/'Extension.entitlements', {
    'com.apple.security.app-sandbox': True,
    'com.apple.security.files.user-selected.read-only': True,
})
