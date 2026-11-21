import plistlib
import sys
from pathlib import Path

app = Path(sys.argv[1])
bundle = 'org.artcraftquicklook.local'
formats = {
    'figcraft': 'ai.storyteller.figcraft.document',
    'designcraft': 'ai.storyteller.designcraft.document',
    'vectorcraft': 'ai.storyteller.vectorcraft.document',
    'tcraft': 'ai.storyteller.texturecraft.project',
    'pcraft': 'ai.storyteller.photocraft.document',
}
def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(plistlib.dumps(data))

def info(name, kind, identifier):
    return dict(CFBundleExecutable=name, CFBundleIdentifier=identifier, CFBundleName=name,
                CFBundleDisplayName='ArtCraft Quick Look', CFBundlePackageType=kind,
                CFBundleVersion='9', CFBundleShortVersionString='0.2.5',
                CFBundleInfoDictionaryVersion='6.0', LSMinimumSystemVersion='13.0',
                CFBundleDevelopmentRegion='it', CFBundleSupportedPlatforms=['MacOSX'])

host = info('ArtCraftQuickLook', 'APPL', bundle)
host['CFBundleIconFile'] = 'ArtCraftQuickLook.icns'
host['UTImportedTypeDeclarations'] = [
    dict(UTTypeIdentifier=uti, UTTypeDescription=f'{ext} document',
         UTTypeTagSpecification={'public.filename-extension':[ext]},
         UTTypeConformsTo=['public.data', 'public.image'] if ext == 'pcraft' else ['public.content', 'public.data'])
    for ext, uti in formats.items()
]
write(app/'Contents/Info.plist', host)
for name, point in [('Preview','preview'),('Thumbnail','thumbnail')]:
    p = info(name, 'XPC!', bundle+'.'+point)
    attrs = dict(QLSupportedContentTypes=[*formats.values(),'com.adobe.photoshop-image'])
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
