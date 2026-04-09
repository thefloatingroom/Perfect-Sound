-- @description Project Specs
-- @version 1.0
-- @author KW
-- @readme_skip
-- @about
--   Show Project Specs
-- @changelog
-- @provides



--[[retval, pist2mics = reaper.GetProjExtState(0, "MICROS", "numero")

if retval==0 then
reaper.InsertTrackAtIndex(4, true)
track=reaper.GetTrack(0, 4)
mon=reaper.GetTrack(0, 1)
reaper.SetMediaTrackInfo_Value(mon, "I_RECINPUT", 3)
reaper.SetMediaTrackInfo_Value(track, "I_RECINPUT", 1026)
reaper.SetMediaTrackInfo_Value(track, "I_RECMON", 0)
reaper.SetMediaTrackInfo_Value(track, "B_MAINSEND", 0)
reaper.CreateTrackSend(track, mon)
reaper.SetTrackSendInfo_Value(track, 0, 0, "I_SENDMODE", 0)
reaper.SetTrackSendInfo_Value(track, 0, 0, "I_SRCCHAN", 1025)
reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "DPA - MKH", true)
reaper.SetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR", 33521664)

reaper.InsertTrackAtIndex(5, true)
track=reaper.GetTrack(0, 5)
reaper.SetMediaTrackInfo_Value(track, "I_RECINPUT", 1026)
reaper.SetMediaTrackInfo_Value(track, "I_RECMON", 0)
reaper.SetMediaTrackInfo_Value(track, "B_MAINSEND", 0)
reaper.SetMediaTrackInfo_Value(track, "B_MUTE", 1)
reaper.CreateTrackSend(track, mon)
reaper.SetTrackSendInfo_Value(track, 0, 0, "I_SENDMODE", 0)
reaper.SetTrackSendInfo_Value(track, 0, 0, "I_SRCCHAN", 1025)
reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "DPA - MKH_ALT01", true)
reaper.SetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR", 33521664)
reaper.SetProjExtState(0, "MICROS", "numero", 1)
end--]]

--scriptspath="'/Volumes/Comun/Programas/Legales/AUDIO/REAPER/Reaper 5 (Commercial License)/Scripts/Dani Scripts/'*.lua"
--localscriptspath="$HOME'/Library/Application Support/REAPER/Scripts/Dani Scripts/'"

--os.execute("cp " .. scriptspath .. " " .. localscriptspath)

reaper.ShowConsoleMsg("Script cargado correctamente\n")

dofile(reaper.GetResourcePath() .. "/Scripts/Perfect-Sound/Core/license.lua")

if not checkLicense() then
  return
end

local texto={}
local letra={}
local parametro={}
local color={}
local rojo={}
local verde={}
local azul={}
local titulos={}
local altol={}
local clickpos={}
local states={}

tipodeletra="Courier"
fontsize=15
separacion=10
Margenizq=40
Margendch=10
margentexto=10
margensup=30
margeninf=10
gfx.setfont(1, tipodeletra, fontsize)
anchotexto, altofont=gfx.measurestr("Head-Tail Silence: ")
a, b, screenx, screeny=reaper.my_getViewport(0, 0, 0, 0, 0, 0, 0, 0, true)
w=(screenx/1.8)-Margenizq-Margendch
anchomax=w-anchotexto-Margenizq-(margentexto*8)
----Warp Text----

function split(text)
  length, alto=gfx.measurestr(text)
  lines=math.floor((length/anchomax)+1)
  if lines==1 then
  sub=text
  else
  space=string.find(text, " ")
    for l=1, lines do
      if length>anchomax then
        while gfx.measurestr(string.sub(text, 0, space))<anchomax do
        line1=string.sub(text, 0, space-1) .. "\n"
        line2=string.sub(text, space+1)
        line=line1 .. line2
        space=string.find(text, " ", space+1)
        end
        text=line
        length=gfx.measurestr(text)
      end
    end
  sub=text
  end
  
  if sub==nil
  then
  sub=""
  end
  
end
---------------------------

color["Recording"]="1,0.4_0.4"
color["Microphone"]="0.7,0.7_1"
color["Editing"]="0.7,1_0.7"
color["Loudness"]="1,1_0.7"
color["FX"]="1,0.7_1"
color["Renaming"]="0.5,0.7_0.9"
color["Delivery"]="0.9,0.6_0.4"
color["Notes"]="0.9,0.9_0.9"
selnormal=1

testspecs=io.open(string.gsub(reaper.GetProjectPath(""), "Audio Files", "Specs.txt"), "r")
if testspecs~=nil then
io.close(testspecs)
else
reaper.ShowMessageBox("El archivo de Specs no se encuentra en la ruta de la sesión.", "¡ATENCIÓN!", 0)
goto final
end

Specs=string.gsub(reaper.GetProjectPath(""), "Audio Files", "Specs.txt")--"C:\\danitools\\regions.txt")
txt = io.open(Specs)
linea=txt:read("*a")
io.close(txt)
txt = io.open(Specs, "w")
txt:write(string.gsub(string.gsub(linea, "\r", "\r\n"), "\n\n", "\n"))
io.close(txt)

txtfile=io.input(Specs)

linea=1
l=0
gfx.setfont(1, tipodeletra, fontsize)
while linea~=nil do
linea=txtfile:read ("*line")
  if linea==nil then break end
  if string.gsub(linea, " ", "")=="" then goto siguiente end
  if string.find(linea, "#")~=nil then
  titulo=string.gsub(linea, "#", "")
  else
  l=l+1
    if string.find(linea, "%*%*")~=nil then
    texto[l]=string.gsub(string.gsub(string.gsub(linea, "%*", ""), ":.+", ""), "Instructions", titulo, 1)
    lineaentera=string.gsub(linea, ".+%*", "")
    split(lineaentera)
    sublength, subalto=gfx.measurestr(sub)
      if subalto>altofont then
      altol[l]=subalto+(subalto/altofont)
      else
      altol[l]=subalto
      end
    parametro[l]=sub
      if color[titulo]==nil then
      rojo[l]=1
      verde[l]=1
      azul[l]=1
      else
      rojo[l]=string.gsub(color[titulo], ",.+", "")
      verde[l]=string.gsub(string.gsub(color[titulo], ".+,", ""), "_.+","")
      azul[l]=string.gsub(color[titulo], ".+_", "")
      end
    titulos[l]=titulo
    states[l]=titulo .. "_" .. texto[l]
    else
    texto[l]=""
    linea=string.gsub(linea, "%*", "")
    split(linea)
    sublength, subalto=gfx.measurestr(sub)
      if subalto>altofont then
      altol[l]=subalto+(subalto/altofont)
      else
      altol[l]=subalto
      end
    parametro[l]=sub
    if color[titulo]==nil then
    rojo[l]=1
    verde[l]=1
    azul[l]=1
    else
    rojo[l]=string.gsub(color[titulo], ",.+", "")
    verde[l]=string.gsub(string.gsub(color[titulo], ".+,", ""), "_.+","")
    azul[l]=string.gsub(color[titulo], ".+_", "")
    end
    titulos[l]=titulo
    states[l]=titulo .. "_" .. texto[l]
    end
  letra[l]=altofont
  end
::siguiente::
end

io.close(txtfile)

    for c=1, l do 
    retval, selnormal = reaper.GetProjExtState(0, "SPECS", states[c])
      if retval==0 then
      reaper.SetProjExtState(0, "SPECS", states[c], 1)
      end
    end


--largo
maslargo=0
for ln=1, l do
length=gfx.measurestr(parametro[ln])
  if length>maslargo then
  maslargo=length
  end
end

altogfx=margensup
for c=1, l do
 altg=altol[c]
   if altg==0 then
   altg=altofont
   end
 altogfx=altogfx+altg+separacion
end

  if gfx.getchar(-1)==-1 then
  gfx.clear=3355443
  gfx.init("", (screenx/1.8), margeninf+altogfx, 0, (screenx/2)-((screenx/1.8)/2), (screeny/2)-(altogfx/2))
  end
 
-------------------------------------------------
function principal() 

estado=gfx.getchar(-1)
if estado==-1 then goto fin end
--notas
a=margensup
pos=margensup
for c=1, l do
 gfx.set(tonumber(rojo[c]), tonumber(verde[c]), tonumber(azul[c]), 1)
 alt=altol[c]
   if alt==0 then
   alt=altofont
   end
 gfx.rect(Margenizq,pos,w,alt+separacion,1)
 gfx.set(0.4, 0.4, 0.4, 1)
   if titulos[c]~="Delivery" and titulos[c]~="Notes" then
    if texto[c]~="" then
    gfx.line(Margenizq-1,pos,Margenizq+w,pos)
    else
      if titulos[c]~=titulos[c+1] and titulos[c]~=titulos[c-1] then
      gfx.line(Margenizq-1,pos,Margenizq+w,pos)
      end
    end
   else
   gfx.line(Margenizq-1,pos,Margenizq+w,pos)
   end
 pos=pos+alt+separacion
 gfx.x=0
 gfx.y=((margensup-altofont)/2)+2
a=a+altofont+separacion
end

 gfx.line(Margenizq-1,pos,Margenizq+w,pos) --Ultima linea
 gfx.line(Margenizq-1,margensup,Margenizq-1,pos) --Linea vertical 1
 gfx.line(Margenizq+(margentexto*2)+anchotexto,margensup,Margenizq+(margentexto*2)+anchotexto,pos) --Linea vertical 2
 gfx.line(w+Margenizq,margensup,w+Margenizq,pos) --Linea vertical 3
 
 --titulos
 d=Margenizq+margentexto
 ancho=gfx.measurestr("Recording")
 gfx.set(0.5, 0.5, 0.5, 1)
 gfx.rect(d,(margensup-altofont)/2,ancho+margentexto,altofont+2,0)
 gfx.set(1, 0.4, 0.4, 1)
 gfx.rect(1+d,((margensup-altofont)/2)+1,ancho+margentexto-2,altofont,1)
 gfx.set(0, 0, 0, 1)
 gfx.x=d+margentexto
 gfx.setfont(1, tipodeletra, fontsize)
 gfx.drawstr("Recording")
 
 d=d+ancho+margentexto+30
 ancho=gfx.measurestr("Microphone")
 gfx.set(0.5, 0.5, 0.5, 1)
 gfx.rect(d,(margensup-altofont)/2,ancho+margentexto,altofont+2,0)
 gfx.set(0.7, 0.7, 1, 1)
 gfx.rect(1+d,((margensup-altofont)/2)+1,ancho+margentexto-2,altofont,1)
 gfx.set(0, 0, 0, 1)
 gfx.x=d+(margentexto/2)
 gfx.setfont(1, tipodeletra, fontsize)
 gfx.drawstr("Microphone")
 
 d=d+ancho+margentexto+30
 ancho=gfx.measurestr("Editing")
 gfx.set(0.5, 0.5, 0.5, 1)
 gfx.rect(d,(margensup-altofont)/2,ancho+margentexto,altofont+2,0)
 gfx.set(0.7, 1, 0.7, 1)
 gfx.rect(1+d,((margensup-altofont)/2)+1,ancho+margentexto-2,altofont,1)
 gfx.set(0, 0, 0, 1)
 gfx.x=d+(margentexto/2)
 gfx.setfont(1, tipodeletra, fontsize)
 gfx.drawstr("Editing")
 
 d=d+ancho+margentexto+30
 ancho=gfx.measurestr("Loudness")
 gfx.set(0.5, 0.5, 0.5, 1)
 gfx.rect(d,(margensup-altofont)/2,ancho+margentexto,altofont+2,0)
 gfx.set(1, 1, 0.7, 1)
 gfx.rect(1+d,((margensup-altofont)/2)+1,ancho+margentexto-2,altofont,1)
 gfx.set(0, 0, 0, 1)
 gfx.x=d+(margentexto/2)
 gfx.setfont(1, tipodeletra, fontsize)
 gfx.drawstr("Loudness")
 
 d=d+ancho+margentexto+30
 ancho=gfx.measurestr("FX")
 gfx.set(0.5, 0.5, 0.5, 1)
 gfx.rect(d,(margensup-altofont)/2,ancho+margentexto,altofont+2,0)
 gfx.set(1, 0.7, 1, 1)
 gfx.rect(1+d,((margensup-altofont)/2)+1,ancho+margentexto-2,altofont,1)
 gfx.set(0, 0, 0, 1)
 gfx.x=d+(margentexto/2)
 gfx.setfont(1, tipodeletra, fontsize)
 gfx.drawstr("FX")

 d=d+ancho+margentexto+30
 ancho=gfx.measurestr("Renaming")
 gfx.set(0.5, 0.5, 0.5, 1)
 gfx.rect(d,(margensup-altofont)/2,ancho+margentexto,altofont+2,0)
 gfx.set(0.5, 0.7, 0.9, 1)
 gfx.rect(1+d,((margensup-altofont)/2)+1,ancho+margentexto-2,altofont,1)
 gfx.set(0, 0, 0, 1)
 gfx.x=d+(margentexto/2)
 gfx.setfont(1, tipodeletra, fontsize)
 gfx.drawstr("Renaming")
 
 d=d+ancho+margentexto+30
 ancho=gfx.measurestr("Delivery")
 gfx.set(0.5, 0.5, 0.5, 1)
 gfx.rect(d,(margensup-altofont)/2,ancho+margentexto,altofont+2,0)
 gfx.set(0.9, 0.6, 0.4, 1)
 gfx.rect(1+d,((margensup-altofont)/2)+1,ancho+margentexto-2,altofont,1)
 gfx.set(0, 0, 0, 1)
 gfx.x=d+(margentexto/2)
 gfx.setfont(1, tipodeletra, fontsize)
 gfx.drawstr("Delivery")
 
 d=d+ancho+margentexto+30
 ancho=gfx.measurestr("Notes")
 gfx.set(0.5, 0.5, 0.5, 1)
 gfx.rect(d,(margensup-altofont)/2,ancho+margentexto,altofont+2,0)
 gfx.set(0.9, 0.9, 0.9, 1)
 gfx.rect(1+d,((margensup-altofont)/2)+1,ancho+margentexto-2,altofont,1)
 gfx.set(0, 0, 0, 1)
 gfx.x=d+(margentexto/2)
 gfx.setfont(1, tipodeletra, fontsize)
 gfx.drawstr("Notes")
  
 gfx.x=5
 gfx.y=10
 gfx.set(1, 1, 1, 1)
 gfx.setfont(1, tipodeletra, fontsize/1.5)
 gfx.drawstr("CHECK")
 
 --texto
 gfx.set(0, 0, 0, 1)
 gfx.y=margensup+(separacion/2)
 for t=1, l do
 gfx.x=Margenizq+margentexto
 
 gfx.setfont(1, tipodeletra, letra[t])
  if texto[t]~="" then
  gfx.drawstr(texto[t])
  else
    if titulos[t]=="Delivery" or titulos[t]=="Notes" then
    gfx.drawstr(titulos[t])
    else
      if titulos[t]~=titulos[t+1] and titulos[t]~=titulos[t-1] then
      gfx.drawstr(titulos[t])
      end
    end
  end
 gfx.x=Margenizq+anchotexto+(margentexto*3)
 gfx.drawstr(parametro[t])
 gfx.y=gfx.y+separacion+altofont
 end
 
 ---Checks
 local check={}
 check[1]=0
 
 d=separacion/2
 
    for c=1, l do 
    retval, selnormal = reaper.GetProjExtState(0, "SPECS", states[c])
     if texto[c]~="" or titulos[c]=="Recording" or titulos[c]=="Microphone" then
     gfx.set(0.5, 0.5, 0.5, 1)
     gfx.rect(11,margensup-1+d,18,18,0)
     gfx.set(selnormal, 1, selnormal, 1)
     gfx.rect(12,margensup+d,16,16,1)
     clickpos[c]=margensup+d
     end
     alt=altol[c]
     if alt>altofont then
     d=d+alt-altofont
     end
    d=d+altofont+(separacion)
    end
    
    if gfx.mouse_cap==1 and gfx.mouse_x>10 and gfx.mouse_x<29 then
    click=gfx.mouse_y
    set=1
    end
    if gfx.mouse_cap==0 and set==1 then
      for cl=1, l do
        if texto[cl]~="" or states[cl]=="Recording_" or states[cl]=="Microphone_" then
          if click>=clickpos[cl] and click<=clickpos[cl]+18 then
          val, st=reaper.GetProjExtState(0, "SPECS", states[cl])
          --reaper.ShowMessageBox(states[cl], st, 0)
            if st=="0" then
            reaper.SetProjExtState(0, "SPECS", states[cl], 1)
            reaper.Main_SaveProject(0, false)
            else
            reaper.SetProjExtState(0, "SPECS", states[cl], 0)
            reaper.Main_SaveProject(0, false)
            end
          set=0
          break
          end     
        end
      end
    end  

 gfx.update()
 reaper.defer(principal)
::fin::
end 

reaper.defer(principal)

::final::
