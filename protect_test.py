import zipfile
import io

def protect_pptx(input_path, output_path):
    out_buf = io.BytesIO()
    has_custom_ui = False
    try:
        with zipfile.ZipFile(input_path, 'r') as zin:
            with zipfile.ZipFile(out_buf, 'w', zipfile.ZIP_DEFLATED) as zout:
                rels_data = None
                for item in zin.infolist():
                    if item.filename == '_rels/.rels':
                        rels_data = zin.read(item.filename)
                    elif 'customUI' in item.filename:
                        has_custom_ui = True
                        zout.writestr(item, zin.read(item.filename))
                    else:
                        zout.writestr(item, zin.read(item.filename))
                
                if not has_custom_ui and rels_data:
                    rels_str = rels_data.decode('utf-8')
                    if '<Relationships' in rels_str:
                        rel_tag1 = '<Relationship Id="rIdCustomUI" Type="http://schemas.microsoft.com/office/2006/relationships/ui/extensibility" Target="customUI/customUI.xml"/>'
                        rel_tag2 = '<Relationship Id="rIdCustomUI14" Type="http://schemas.microsoft.com/office/2007/relationships/ui/extensibility" Target="customUI/customUI14.xml"/>'
                        rels_str = rels_str.replace('</Relationships>', rel_tag1 + rel_tag2 + '</Relationships>')
                        zout.writestr('_rels/.rels', rels_str.encode('utf-8'))
                        
                        custom_ui_2007 = b'''<customUI xmlns="http://schemas.microsoft.com/office/2006/01/customui">
  <commands>
    <command idMso="FileSave" enabled="false"/>
    <command idMso="FileSaveAs" enabled="false"/>
    <command idMso="SaveAs" enabled="false"/>
  </commands>
</customUI>'''

                        custom_ui_2010 = b'''<customUI xmlns="http://schemas.microsoft.com/office/2009/07/customui">
  <commands>
    <command idMso="FileSave" enabled="false"/>
    <command idMso="FileSaveAs" enabled="false"/>
    <command idMso="SaveAs" enabled="false"/>
  </commands>
</customUI>'''
                        zout.writestr('customUI/customUI.xml', custom_ui_2007)
                        zout.writestr('customUI/customUI14.xml', custom_ui_2010)
                    else:
                        zout.writestr('_rels/.rels', rels_data)
                elif rels_data:
                    zout.writestr('_rels/.rels', rels_data)
    except Exception as e:
        print("Error:", e)
        return False
        
    with open(output_path, 'wb') as f:
        f.write(out_buf.getvalue())
    return True

print(protect_pptx('sample.pptx', 'sample_protected.pptx'))
