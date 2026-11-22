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
    folder=d/'package.pcraft'; (folder/'composite').mkdir(parents=True)
    (folder/'manifest.json').write_bytes(b'{}'); (folder/'composite/preview.png').write_bytes(red)
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
    (d/'input.png').write_bytes(red)
    header=struct.pack('>4sH6xHIIHH',b'8BPS',1,3,2,2,8,3)
    (d/'image.psd').write_bytes(header + bytes(14) + bytes([255])*4 + bytes(8))
    (d/'broken.figcraft').write_bytes(b'PK\x03\x04')
    (d/'absent.tcraft').write_bytes(zipped({'project.json':b'{}'}))
    (d/'wrong.figcraft').write_bytes(zipped({'thumbnail.png':red}))
    (d/'other.drawcraft').write_bytes(vector)
    (d/'oversized.figcraft').write_bytes(zipped({'document.json':b'{}','thumbnail.png':b'x'*(33<<20)}))
    (d/'forged.psd').write_bytes(red)
    escape=d/'escape.pcraft'; (escape/'composite').mkdir(parents=True)
    (escape/'manifest.json').write_bytes(b'{}'); (escape/'composite'/'preview.png').symlink_to(d/'input.png')

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
        for name in ['fig.figcraft','design.designcraft','texture.tcraft','photo.pcraft','vector.vectorcraft','compressed.vectorcraft','stream.vectorcraft','inline-pdf.vectorcraft','linked-pdf.vectorcraft','compressed-pdf.vectorcraft','package.pcraft','image.psd']:
            result=subprocess.run([command,d/name],capture_output=True)
            assert result.returncode==0,(name,result.stderr)
            expected='2048x2048 ff0000' if '-pdf.vectorcraft' in name else '2x2 ff0000'
            assert result.stdout.decode().strip()==expected,(name,result.stdout)
            checks+=1
        # A SoundCraft session is drawn as its timeline, on a square card whatever its tracks and length.
        for name in ['session.scraft','crowded.scraft','solo.scraft']:
            result=subprocess.run([command,d/name],capture_output=True)
            assert result.returncode==0 and result.stdout.decode().split()[0]=='2048x2048',(name,result.stdout,result.stderr)
            checks+=1
        for name in ['notes.scraft','broken.figcraft','absent.tcraft','wrong.figcraft','other.drawcraft','oversized.figcraft','forged.psd','escape.pcraft']:
            result=subprocess.run([command,d/name],capture_output=True)
            assert result.returncode!=0,(name,result.stdout)
            checks+=1
        print(f'{checks} verifiche riuscite')
