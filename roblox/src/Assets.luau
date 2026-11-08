local Assets={ Cards = "rbxassetid://116910231927744", CardWidth = 72, CardHeight = 100,
 Portraits = "rbxassetid://134082763828827", PortraitWidth = 200, PortraitHeight = 200,
 LoadoutAtlas="rbxassetid://86798104751689",LoadoutWidth=683,LoadoutHeight=1024,
 Tarot={candle="rbxassetid://137978481106034",tower="rbxassetid://119812479439200",scales="rbxassetid://110912142893854",seal="rbxassetid://88778262837898",echo="rbxassetid://109217339038049",sun="rbxassetid://114121721951074",coin="rbxassetid://128665993134527",rose="rbxassetid://72227471886347",thread="rbxassetid://71467474698283",hourglass="rbxassetid://112005936945493",guardian="rbxassetid://128673203253779",moon="rbxassetid://90050084021940"},
 RaceAtlas="rbxassetid://87719532143821",RaceAtlasW=720,RaceAtlasH=960,RaceAtlasCols=5,RaceCellW=144,RaceCellH=240,
 Source = "Original VOCHKO artwork exported from the repository; see assets/README.md" }
-- Race arcana atlas order (top-left to bottom-right in race-tarot-atlas.png).
local raceArtIndex={rose=0,guardian=1,sun=2,moon=3,scales=4,candle=5,clock=6,focus=7,wheel=8,justice=9,
 poison=10,rust=11,chain=12,load=13,tower=14,darkening=15,hanged=16,jester=17,thief=18,death=19}
local symbols={rose="♥",guardian="◇",sun="☀",moon="☽",tower="♜",coin="$",echo="×",seal="⬡",scales="⚖",candle="✦",thread="∞",hourglass="⌛"}
local loadoutCells={class={sharp=0,healer=1,guardian=2},joker={crimson=3,blot=4,triple=5,tandem=6,ladder=7,xray=8}}
function Assets.CreateLoadoutArt(parent,kind,id)
 local index=loadoutCells[kind]and loadoutCells[kind][id];if index==nil then return nil end
 local x=index%3;local y=math.floor(index/3)
 local left,right=math.floor(x*Assets.LoadoutWidth/3),math.floor((x+1)*Assets.LoadoutWidth/3)
 local top,bottom=math.floor(y*Assets.LoadoutHeight/3),math.floor((y+1)*Assets.LoadoutHeight/3)
 local image=Instance.new('ImageLabel');image.Name='LoadoutArt';image.BackgroundTransparency=1;image.Size=UDim2.fromScale(1,1)
 image.Image=Assets.LoadoutAtlas;image.ImageRectOffset=Vector2.new(left+2,top+2);image.ImageRectSize=Vector2.new(right-left-4,bottom-top-4);image.ScaleType=Enum.ScaleType.Fit;image.Parent=parent
 return image
end
-- Keep the card identifiable even when moderation, permissions or a slow fetch
-- prevent the illustration from loading in the published experience.
function Assets.CreateTarotArt(parent,id)
 local fallback=Instance.new("TextLabel");fallback.Name="TarotFallback"
 fallback.Size=UDim2.fromScale(1,1);fallback.BackgroundColor3=Color3.fromRGB(35,49,38)
 fallback.BorderSizePixel=0;fallback.Text=symbols[id]or "✦";fallback.Font=Enum.Font.Garamond
 fallback.TextScaled=true;fallback.TextColor3=Color3.fromRGB(226,192,122);fallback.Parent=parent
 local art=Instance.new("ImageLabel");art.Name="TarotArt"
 art.Size=UDim2.fromScale(1,1);art.BackgroundTransparency=1;art.ScaleType=Enum.ScaleType.Fit;art.Parent=parent
 local cell=raceArtIndex[id]
 if cell and Assets.RaceAtlas~="rbxassetid://0"then
  local col,row=cell%Assets.RaceAtlasCols,math.floor(cell/Assets.RaceAtlasCols)
  art.Image=Assets.RaceAtlas
  art.ImageRectOffset=Vector2.new(col*Assets.RaceCellW,row*Assets.RaceCellH)
  art.ImageRectSize=Vector2.new(Assets.RaceCellW,Assets.RaceCellH)
 else
  art.Image=Assets.Tarot[id]or ""
 end
 local function refresh()fallback.Visible=not art.IsLoaded end
 art:GetPropertyChangedSignal("IsLoaded"):Connect(refresh);refresh()
 task.spawn(function()
  pcall(function()game:GetService("ContentProvider"):PreloadAsync({art})end)
  if art.Parent and fallback.Parent then refresh()end
 end)
 return art
end
local warmed=false
local fetchReport={}
function Assets.GetLoadReport()return table.clone(fetchReport)end
function Assets.PreloadAll()
 if warmed then return end;warmed=true
 task.spawn(function()
  -- Raw rbxassetid strings can take a different resolution path: reproduced
  -- Failure for a string and Success for the same ImageLabel.Image in Studio.
  -- Give ContentProvider typed image dependencies, including on cold startup.
  local images={}
  local function add(id)local image=Instance.new('ImageLabel');image.Image=id;table.insert(images,image)end
  add(Assets.Cards);add(Assets.Portraits);add(Assets.LoadoutAtlas);add(Assets.RaceAtlas)
  for _,id in Assets.Tarot do add(id)end
  local ok,err=pcall(function()
   game:GetService("ContentProvider"):PreloadAsync(images,function(id,status)
    fetchReport[id]=tostring(status)
    if status~=Enum.AssetFetchStatus.Success then warn("[VOCHKO Art] ImageLabel preload failed: "..id.." "..tostring(status).."; universe="..game.GameId)end
   end)
  end)
  for _,image in images do image:Destroy()end
  if not ok then warn("[VOCHKO Art] preload: "..tostring(err))end
 end)
end
function Assets.WarmTarot()Assets.PreloadAll()end
return table.freeze(Assets)
