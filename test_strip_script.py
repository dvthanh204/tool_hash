import zipfile
import re
import io

def protect_pptx(input_path):
    out_buf = io.BytesIO()
    has_custom_ui = False
    try:
        with zipfile.ZipFile(input_path, 'r') as zin:
            with zipfile.ZipFile(out_buf, 'w', zipfile.ZIP_DEFLATED) as zout:
                rels_data = None
                for item in zin.infolist():
                    if item.filename.startswith('ppt/fonts/'):
                        continue
                        
                    if item.filename == '_rels/.rels':
                        rels_data = zin.read(item.filename)
                    elif item.filename == 'ppt/presentation.xml':
                        p_data = zin.read(item.filename).decode('utf-8')
                        p_data = re.sub(r'<p:embeddedFontLst>.*?</p:embeddedFontLst>', '', p_data, flags=re.DOTALL)
                        p_data = re.sub(r'<p:embeddedFontLst\b[^>]*/>', '', p_data)
                        zout.writestr(item, p_data.encode('utf-8'))
                    elif item.filename == 'ppt/_rels/presentation.xml.rels':
                        rels_str = zin.read(item.filename).decode('utf-8')
                        rels_str = re.sub(r'<Relationship[^>]*relationships/font[^>]*/>', '', rels_str)
                        zout.writestr(item, rels_str.encode('utf-8'))
                    elif 'customUI' in item.filename:
                        has_custom_ui = True
                        zout.writestr(item, zin.read(item.filename))
                    else:
                        zout.writestr(item, zin.read(item.filename))
    except Exception as e:
        print('Error:', e)
    return out_buf.getvalue()

# Create a test pptx with fonts
with zipfile.ZipFile('test_font_course.pptx', 'w') as zf:
    zf.writestr('_rels/.rels', '<Relationships><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/></Relationships>')
    zf.writestr('ppt/fonts/testfont.fntdata', 'dummy font data')
    zf.writestr('ppt/_rels/presentation.xml.rels', '<Relationships><Relationship Id="rIdFont" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/font" Target="fonts/testfont.fntdata"/></Relationships>')
    zf.writestr('ppt/presentation.xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation><p:embeddedFontLst><p:embeddedFont><p:font /></p:embeddedFont></p:embeddedFontLst></p:presentation>''')

res = protect_pptx('test_font_course.pptx')
with open('test_protected.pptx', 'wb') as f:
    f.write(res)

print('\n--- TEST RESULTS ---')
with zipfile.ZipFile('test_protected.pptx', 'r') as z:
    names = z.namelist()
    print('Checking fonts folder removed:', 'ppt/fonts/testfont.fntdata' not in names)
    
    xml_data = z.read('ppt/presentation.xml').decode('utf-8')
    print('Checking presentation.xml tagging removed:', '<p:embeddedFontLst' not in xml_data)
    
    rels_data = z.read('ppt/_rels/presentation.xml.rels').decode('utf-8')
    print('Checking relationships filtering removed:', 'relationships/font' not in rels_data)
    print('--------------------\nTEST COMPLETE!')
