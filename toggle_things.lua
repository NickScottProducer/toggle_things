-- Initialize variables for FX management
local fx_is_running = false
local list1 = {}  -- List to store FX in the first group
local list2 = {}  -- List to store FX in the second group
local bypass_state = {}    -- To track bypass state of each FX ID
local fx_list = {}        -- To track which FX is in which list
local current_fx_list_selection = 1  -- 1 for list1, 2 for list2

-- Initialize variables for track management
local track_is_running = false
local track_list1 = {}  -- List to store tracks in the first group
local track_list2 = {}  -- List to store tracks in the second group
local last_selected_track = nil  -- Variable to keep track of the most recently selected track
local current_track_list_selection = 1  -- 1 for track_list1, 2 for track_list2

-- Variable to control GUI visibility
local gui_visible = true

-- Function to get the currently focused FX
local function get_focused_fx()
    local track_count = reaper.CountTracks(0)
    
    -- Iterate through all tracks
    for t = 0, track_count - 1 do
        local track = reaper.GetTrack(0, t)
        if track then
            local fx_count = reaper.TrackFX_GetCount(track)
            
            -- Check each FX on the track
            for f = 0, fx_count - 1 do
                -- Get FX identifier (GUID)
                local fx_id = reaper.TrackFX_GetFXGUID(track, f)
                
                -- Check if this FX is the currently focused one
                if reaper.TrackFX_GetOpen(track, f) then
                    -- Retrieve FX name
                    local _, fx_name = reaper.TrackFX_GetFXName(track, f, "")
                    
                    if fx_id ~= last_touched_fx_id then
                        -- Update last touched FX and track
                        last_touched_fx_id = fx_id or "Unknown"
                        last_touched_fx_name = fx_name or "Unknown"
                        last_touched_fx_track = "Track " .. (t + 1)
                        
                        -- Add to the appropriate list based on the current selection
                        local selected_list = current_fx_list_selection == 1 and list1 or list2
                        if not fx_list[fx_id] then
                            table.insert(selected_list, {fx_id = last_touched_fx_id, fx_name = last_touched_fx_name, track = track, slot = f})
                            bypass_state[last_touched_fx_id] = reaper.TrackFX_GetEnabled(track, f) -- Store the initial state
                            fx_list[fx_id] = current_fx_list_selection
                        end

                        -- Update the last FX ID
                        last_touched_fx_id = fx_id
                    end
                    return
                end
            end
        end
    end
end

-- Function to toggle bypass state between two FX lists
local function toggle_fx_bypass()
    if #list1 < 1 or #list2 < 1 then return end -- Ensure both lists have at least 1 FX
    
    local function toggle_list(list)
        for _, fx in ipairs(list) do
            local track = fx.track
            local fx_index = fx.slot
            local current_state = reaper.TrackFX_GetEnabled(track, fx_index)
            local new_state = not current_state
            reaper.TrackFX_SetEnabled(track, fx_index, new_state)
            bypass_state[fx.fx_id] = new_state -- Update the stored state
        end
    end

    -- Toggle all FX in list1 and list2
    toggle_list(list1)
    toggle_list(list2)
end

-- Function to update the last selected track
local function update_selected_track()
    local count_selected_tracks = reaper.CountSelectedTracks(0)
    if count_selected_tracks > 0 then
        local track = reaper.GetSelectedTrack(0, count_selected_tracks - 1)
        if track and track ~= last_selected_track then
            local selected_list = current_track_list_selection == 1 and track_list1 or track_list2
            table.insert(selected_list, track)
            last_selected_track = track
        end
    end
end

-- Function to toggle mute between tracks in the two lists
local function toggle_track_mute()
    if #track_list1 < 1 or #track_list2 < 1 then return end -- Ensure both lists have at least 1 track

    local function toggle_list(list)
        for _, track in ipairs(list) do
            local is_muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1
            reaper.SetMediaTrackInfo_Value(track, "B_MUTE", is_muted and 0 or 1)
        end
    end

    -- Toggle mute state for tracks in both lists
    toggle_list(track_list1)
    toggle_list(track_list2)
end

-- Function to clear cache/history
local function clear_cache()
    list1 = {}
    list2 = {}
    track_list1 = {}
    track_list2 = {}
    fx_list = {}
    bypass_state = {}
    last_selected_track = nil
end

-- Function to create the GUI
local function create_gui()
    local ctx = reaper.ImGui_CreateContext("FX & Track Management")

    local function gui()
        if not gui_visible then return end -- Check visibility flag

        reaper.ImGui_SetNextWindowSize(ctx, 600, 400, reaper.ImGui_Cond_FirstUseEver())
        
        if reaper.ImGui_Begin(ctx, 'FX & Track Management', true) then
            -- FX Management
            reaper.ImGui_Text(ctx, "FX Management:")
            if not fx_is_running then
                if reaper.ImGui_Button(ctx, 'Start FX Tracking') then
                    fx_is_running = true
                    last_touched_fx_name = "Tracking started. Click an FX to see its name here."
                end
            else
                if reaper.ImGui_Button(ctx, 'Stop FX Tracking') then
                    fx_is_running = false
                    last_touched_fx_name = "Tracking stopped."
                end
            end

            if fx_is_running then
                get_focused_fx()
            end

            reaper.ImGui_Text(ctx, "FX Name: " .. (last_touched_fx_name or "No FX clicked"))
            reaper.ImGui_Text(ctx, "Track: " .. (last_touched_fx_track or "No Track Selected"))

            reaper.ImGui_Separator(ctx)
            reaper.ImGui_Text(ctx, "List 1 FX Names:")
            for _, fx in ipairs(list1) do
                reaper.ImGui_Text(ctx, fx.fx_name)
            end

            reaper.ImGui_Separator(ctx)
            reaper.ImGui_Text(ctx, "List 2 FX Names:")
            for _, fx in ipairs(list2) do
                reaper.ImGui_Text(ctx, fx.fx_name)
            end

            if reaper.ImGui_Button(ctx, 'Toggle Bypass Between FX Lists') then
                toggle_fx_bypass()
            end

            if reaper.ImGui_Button(ctx, 'Add to FX List 1') then
                current_fx_list_selection = 1
                last_touched_fx_name = "Added to FX List 1"
            end
            if reaper.ImGui_Button(ctx, 'Add to FX List 2') then
                current_fx_list_selection = 2
                last_touched_fx_name = "Added to FX List 2"
            end

            -- Track Management
            reaper.ImGui_Separator(ctx)
            reaper.ImGui_Text(ctx, "Track Management:")
            if not track_is_running then
                if reaper.ImGui_Button(ctx, 'Start Tracking Selected Tracks') then
                    track_is_running = true
                end
            else
                if reaper.ImGui_Button(ctx, 'Stop Tracking') then
                    track_is_running = false
                end
            end

            if track_is_running then
                update_selected_track()
            end

            reaper.ImGui_Separator(ctx)
            reaper.ImGui_Text(ctx, "Tracks in List 1:")
            for i, track in ipairs(track_list1) do
                local retval, track_name = reaper.GetTrackName(track, "")
                reaper.ImGui_Text(ctx, (i) .. ". " .. (track_name or "Unknown"))
            end

            reaper.ImGui_Separator(ctx)
            reaper.ImGui_Text(ctx, "Tracks in List 2:")
            for i, track in ipairs(track_list2) do
                local retval, track_name = reaper.GetTrackName(track, "")
                reaper.ImGui_Text(ctx, (i) .. ". " .. (track_name or "Unknown"))
            end

            if reaper.ImGui_Button(ctx, 'Toggle Mute Between Tracks') then
                toggle_track_mute()
            end

            if reaper.ImGui_Button(ctx, 'Add to Track List 1') then
                current_track_list_selection = 1
            end
            if reaper.ImGui_Button(ctx, 'Add to Track List 2') then
                current_track_list_selection = 2
            end

            -- Master Toggle Button
            if reaper.ImGui_Button(ctx, 'Master Toggle') then
                toggle_fx_bypass()
                toggle_track_mute()
            end

            -- Button to clear cache/history
            if reaper.ImGui_Button(ctx, 'Clear Cache') then
                clear_cache()
            end

            -- Close Button
            if reaper.ImGui_Button(ctx, 'Close') then
                gui_visible = false
            end

            reaper.ImGui_End(ctx)
        end

        if gui_visible then
            reaper.defer(gui) -- Continue the GUI loop
        end
    end
    
    reaper.defer(gui) -- Start the GUI loop
end

-- Main function to initialize the script
create_gui()
