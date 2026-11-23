import base64, gzip, io, json, os, pathlib, struct, subprocess, sys, tempfile, zipfile, zlib

def png(r,g,b):
    def chunk(tag,data): return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data))
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>2I5B',2,2,8,2,0,0,0))+chunk(b'IDAT',zlib.compress((b'\0'+bytes([r,g,b])*2)*2))+chunk(b'IEND',b'')

def zipped(entries):
    b=io.BytesIO()
    with zipfile.ZipFile(b,'w',zipfile.ZIP_DEFLATED) as z:
        for name,value in entries.items(): z.writestr(name,value)
    return b.getvalue()

def red_pdf():
    drawing=b'1 0 0 rg 0 0 200 200 re f\n'
    objects=[
        b'<< /Type /Catalog /Pages 2 0 R >>',
        b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
        b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << >> /Contents 4 0 R >>',
        b'<< /Length %d >>\nstream\n'%len(drawing)+drawing+b'\nendstream',
    ]
    data=b'%PDF-1.4\n'
    offsets=[]
    for i,obj in enumerate(objects,1):
        offsets.append(len(data)); data+=b'%d 0 obj\n'%i+obj+b'\nendobj\n'
    end=len(data)
    data+=b'xref\n0 5\n0000000000 65535 f \n'
    for offset in offsets: data+=b'%010d 00000 n \n'%offset
    return data+b'trailer << /Size 5 /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n'%end

def all_files(d):
    red=png(255,0,0)
    green=png(0,255,0)
    vector=json.dumps({'format':'vectorcraft','version':4,'preview':{'mime':'image/png','data':base64.b64encode(red).decode()}}).encode()
    pdf=red_pdf()
    head={'format':'vectorcraft','version':4}
    pdf_inline=json.dumps({**head,'pdf':{'mime':'application/pdf','data':base64.b64encode(pdf).decode()}}).encode()
    pdf_blob=json.dumps({**head,'pdf':{'mime':'application/pdf','blob':[0,len(pdf)]}}).encode()+b'\n\0VCBLOBS\0'+pdf
    for name,data in {
        'inline-pdf.vectorcraft':pdf_inline,
        'linked-pdf.vectorcraft':pdf_blob,
        'compressed-pdf.vectorcraft':gzip.compress(pdf_blob),
        'fig.figcraft':zipped({'document.json':b'{}','thumbnail.png':red}),
        'design.designcraft':zipped({'document.json':b'{}','preview.png':red}),
        'texture.tcraft':zipped({'project.json':b'{}','thumbnail.png':red}),
        'photo.pcraft':zipped({'manifest.json':b'{}','thumb.png':green,'composite/preview.png':red}),
        'vector.vectorcraft':vector,
        'compressed.vectorcraft':gzip.compress(vector),
        'stream.vectorcraft':vector+b'\nVCBLOB1more data',
    }.items(): (d/name).write_bytes(data)
    session={'format_version':1,'name':'Prova','sample_rate':48000,'tempo':{'tempos':[{'tick':0,'bpm':120.0}],'meters':[{'tick':0,'numerator':4,'denominator':4}]},
             'markers':[{'name':'Strofa','start':96000}],'edit':{'playhead':48000},
             'tracks':[{'name':'Basso','kind':'Audio','color':[150,98,206],'active_playlist':0,'playlists':[{'clips':[{'name':'Basso','start':0,'length':192000}]}]},
                       {'name':'Tastiere','kind':'Instrument','color':[80,190,168],'active_playlist':0,'playlists':[{'clips':[{'name':'Accordi','start':48000,'length':96000,
                        'content':{'Midi':{'sequence':{'notes':[{'pitch':60,'start':0,'length':900},{'pitch':64,'start':960,'length':900}]}}}}]}]}]}
    (d/'session.scraft').write_text(json.dumps(session))
    crowded=dict(session,name='Affollata',tracks=[dict(session['tracks'][0],name=f'Traccia {i}',playlists=[{'clips':[{'name':'Clip','start':i*48000*60,'length':48000*30}]}]) for i in range(64)])
    (d/'crowded.scraft').write_text(json.dumps(crowded))
    (d/'solo.scraft').write_text(json.dumps(dict(session,name='Sola',tracks=session['tracks'][:1])))
    (d/'notes.scraft').write_text(json.dumps({'name':'Senza formato','tracks':[]}))
    # Values no session has: they are brought into range and the timeline is still drawn (choice
    # Scraft-01). Before 0.5.1 each of them trapped on an Int conversion and took the extension down.
    clip=session['tracks'][1]['playlists'][0]['clips'][0]
    hostile={
        'tiny-rate.scraft':dict(session,sample_rate=1e-300),
        'huge-rate.scraft':dict(session,sample_rate=1e300),
        'huge-bpm.scraft':dict(session,tempo={'tempos':[{'tick':0,'bpm':1e300}],'meters':[{'tick':0,'numerator':1e300,'denominator':1e-300}]}),
        'far-clip.scraft':dict(session,tracks=[dict(session['tracks'][0],playlists=[{'clips':[{'name':'Lontano','start':1e19,'length':1e19}]}])]),
        'far-marker.scraft':dict(session,markers=[{'name':'Fine','start':1e300}],edit={'playhead':1e300}),
        'wild-pitch.scraft':dict(session,tracks=[dict(session['tracks'][1],playlists=[{'clips':[dict(clip,content={'Midi':{'sequence':{'notes':[
            {'pitch':-9_000_000_000_000_000_000,'start':0,'length':900},{'pitch':9_000_000_000_000_000_000,'start':960,'length':1e300}]}}})]}])]),
    }
    for name,value in hostile.items(): (d/name).write_text(json.dumps(value))
    (d/'input.png').write_bytes(red)
    header=struct.pack('>4sH6xHIIHH',b'8BPS',1,3,2,2,8,3)
    (d/'image.psd').write_bytes(header + bytes(14) + bytes([255])*4 + bytes(8))
    (d/'broken.figcraft').write_bytes(b'PK\x03\x04')
    (d/'absent.tcraft').write_bytes(zipped({'project.json':b'{}'}))
    (d/'wrong.figcraft').write_bytes(zipped({'thumbnail.png':red}))
    (d/'other.drawcraft').write_bytes(vector)
    # A real PNG, padded past the 32 MiB image limit with an ancillary chunk, so only the limit rejects it.
    # The same padding under the limit is the control: that PNG must still be read.
    def padded(size):
        red_png=png(255,0,0); padding=b'x'*size
        return red_png[:-12]+struct.pack('>I',size)+b'tEXt'+padding+struct.pack('>I',zlib.crc32(b'tEXt'+padding))+red_png[-12:]
    (d/'oversized.figcraft').write_bytes(zipped({'document.json':b'{}','thumbnail.png':padded(33<<20)}))
    (d/'padded.figcraft').write_bytes(zipped({'document.json':b'{}','thumbnail.png':padded(1<<20)}))
    (d/'forged.psd').write_bytes(red)

if __name__=='__main__':
    command=pathlib.Path(sys.argv[1]).resolve()
    assert command.is_file(), 'The preview renderer has not been built'
    if len(sys.argv)>2:
        target=pathlib.Path(sys.argv[2]); target.mkdir(parents=True,exist_ok=True); all_files(target); sys.exit()
    checks=0
    # A Retina thumbnail: 128 x 64 points at scale 2 arrive as a 256 x 128 pixel context.
    result=subprocess.run([command,'--fill','256','128'],capture_output=True)
    assert result.returncode==0 and result.stdout.decode().split()==['ff0000']*4,('fill',result.stdout,result.stderr)
    checks+=1
    with tempfile.TemporaryDirectory() as tmp:
        d=pathlib.Path(tmp); all_files(d)
        for name in ['fig.figcraft','padded.figcraft','design.designcraft','texture.tcraft','photo.pcraft','vector.vectorcraft','compressed.vectorcraft','stream.vectorcraft','inline-pdf.vectorcraft','linked-pdf.vectorcraft','compressed-pdf.vectorcraft','image.psd']:
            result=subprocess.run([command,d/name],capture_output=True)
            assert result.returncode==0,(name,result.stderr)
            expected='2048x2048 ff0000' if '-pdf.vectorcraft' in name else '2x2 ff0000'
            assert result.stdout.decode().strip()==expected,(name,result.stdout)
            checks+=1
        # A SoundCraft session is drawn as its timeline, on a square card whatever its tracks and length.
        for name in ['session.scraft','crowded.scraft','solo.scraft','tiny-rate.scraft','huge-rate.scraft','huge-bpm.scraft','far-clip.scraft','far-marker.scraft','wild-pitch.scraft']:
            result=subprocess.run([command,d/name],capture_output=True)
            assert result.returncode==0 and result.stdout.decode().split()[0]=='2048x2048',(name,result.stdout,result.stderr)
            checks+=1
        # A rejected file ends with status 1 and a message: a crash (a signal, a negative status)
        # used to count as a rejection, and hid the SoundCraft traps above.
        for name in ['notes.scraft','broken.figcraft','absent.tcraft','wrong.figcraft','other.drawcraft','oversized.figcraft','forged.psd']:
            result=subprocess.run([command,d/name],capture_output=True)
            assert result.returncode==1 and result.stderr,(name,result.returncode,result.stdout)
            checks+=1
        # Linked SVG files: the renderer's own file names are refused in any letter case, and at most
        # 32 files and 64 MiB in all reach the renderer.
        red=png(255,0,0); links=d/'links'; links.mkdir()
        names=['preview.png','CraftLook-Input.SVG','craftlook-document.svg','craftlook-output.png']+[f'n{i:02d}.png' for i in range(40)]
        for name in names: (links/name).write_bytes(red)
        (links/'drawing.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg">'+''.join(f'<image href="{n}"/>' for n in names)+'</svg>')
        result=subprocess.run([command,'--svg-resources',links/'drawing.svg'],capture_output=True)
        expected=sorted(['preview.png']+[f'n{i:02d}.png' for i in range(31)])
        assert result.returncode==0 and result.stdout.decode().split()==expected,('svg names',result.stdout,result.stderr)
        checks+=1
        for name in ['b1.png','b2.png','b3.png']: (links/name).write_bytes(red+b'\0'*(30<<20))
        (links/'big.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg"><image href="b1.png"/><image href="b2.png"/><image href="b3.png"/></svg>')
        result=subprocess.run([command,'--svg-resources',links/'big.svg'],capture_output=True)
        assert result.returncode==0 and result.stdout.decode().split()==['b1.png','b2.png'],('svg total',result.stdout,result.stderr)
        checks+=1
        print(f'{checks} verifiche riuscite')
