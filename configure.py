import plistlib
import sys
from pathlib import Path

app = Path(sys.argv[1])
# Without renderers (build.sh with no renderer folder) the extensions read only the pictures saved in
# the files: they must not claim the formats only a renderer can show, or Quick Look would send those
# files to them instead of to macOS's own previews.
embedded_only = '--embedded-only' in sys.argv[2:]
bundle = 'com.roccobot.craftlook'
PUBLIC_ED_KEY = 'iOrWlpw4J6LLf7J8WvKwKiECiEMDbMWJ183pypWdrk4='
# The project types: UTI, extensions and conformance. SolidCraft, FilmCraft, MaterialCraft,
# EffectCraft and SoundCraft repeat the declaration their own app exports.
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
    'ai.storyteller.soundcraft.session': (['scraft'], ['public.data', 'public.content']),
}
# Types macOS declares itself, so they are only listed in the extensions.
system_types = ['com.adobe.photoshop-image', 'public.svg-image']
# The types whose picture CraftLook finds without a renderer: a saved image, an embedded PDF, a composite,
# or the timeline it draws itself.
readable = {'ai.storyteller.figcraft.document', 'ai.storyteller.designcraft.document',
            'ai.storyteller.vectorcraft.document', 'ai.storyteller.texturecraft.project',
            'ai.storyteller.photocraft.document', 'ai.storyteller.soundcraft.session',
            'com.adobe.photoshop-image'}
handled = [t for t in [*formats, *system_types] if not embedded_only or t in readable]
def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(plistlib.dumps(data))

def info(name, kind, identifier):
    return dict(CFBundleExecutable=name, CFBundleIdentifier=identifier, CFBundleName=name,
                CFBundleDisplayName='CraftLook', CFBundlePackageType=kind,
                CFBundleVersion='16', CFBundleShortVersionString='0.5.1',
                CFBundleInfoDictionaryVersion='6.0', LSMinimumSystemVersion='13.0',
                LSArchitecturePriority=['arm64'], LSRequiresNativeExecution=True,
                CFBundleDevelopmentRegion='en', CFBundleSupportedPlatforms=['MacOSX'])

host = info('CraftLook', 'APPL', bundle)
host['CFBundleIconFile'] = 'CraftLook.icns'
host['NSHumanReadableCopyright'] = '© 2026 Rocco Casadei, a.k.a. Roccobot'
# Sparkle (Rules.md, 'Aggiornamenti'): the appcast published with each release, the public half of
# the EdDSA key that signs the update archives (account craftlook of Rocco's keychain), a check a
# day while the app runs, and a question before installing. The app is not sandboxed, so Sparkle's
# XPC services are not needed.
host.update(SUFeedURL='https://github.com/Roccobot/CraftLook/releases/latest/download/appcast.xml',
            SUPublicEDKey=PUBLIC_ED_KEY, SUEnableAutomaticChecks=True, SUAutomaticallyUpdate=False,
            SUScheduledCheckInterval=86400)
host['UTImportedTypeDeclarations'] = [
    dict(UTTypeIdentifier=uti, UTTypeDescription=f'{extensions[0]} document',
         UTTypeTagSpecification={'public.filename-extension': extensions}, UTTypeConformsTo=conforms)
    for uti, (extensions, conforms) in formats.items()
]
write(app/'Contents/Info.plist', host)
for name, point in [('Preview','preview'),('Thumbnail','thumbnail')]:
    p = info(name, 'XPC!', bundle+'.'+point)
    attrs = dict(QLSupportedContentTypes=handled)
    if name == 'Preview':
        attrs.update(QLIsDataBasedPreview=True, QLSupportsSearchableItems=False)
    else:
        attrs['QLThumbnailMinimumDimension'] = 0
    p['NSExtension'] = dict(NSExtensionPointIdentifier='com.apple.quicklook.'+point,
                          NSExtensionPrincipalClass=f'{name}.{name}Provider',
                          NSExtensionAttributes=attrs)
    write(app/f'Contents/PlugIns/{name}.appex/Contents/Info.plist', p)
# The renderer service, a thin XPC in each Quick Look extension. Both run the same Helpers
# in the app (Contents/Helpers), the one copy of the renderers.
for name, point in [('Preview','preview'),('Thumbnail','thumbnail')]:
    service = info('CraftRender', 'XPC!', bundle + '.' + point + '.render')
    service['XPCService'] = {'ServiceType': 'Application'}
    write(app/f'Contents/PlugIns/{name}.appex/Contents/XPCServices/CraftRender.xpc/Contents/Info.plist', service)
write(app.parent/'Service.entitlements', {'com.apple.security.app-sandbox': True})
write(app.parent/'Extension.entitlements', {
    'com.apple.security.app-sandbox': True,
    'com.apple.security.files.user-selected.read-only': True,
})
