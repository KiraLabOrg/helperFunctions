function createAcq(mouse_num,date_num,FOV_num,Acq_num,varargin)

    varargin2V(varargin);

    initials = getInitialsKL(mouse_num);
    mouseID = sprintf('%s%03d',initials,mouse_num);
    server_name = 'scratch2';
    o2_flag = false;

    if nargin < 3 || isempty(FOV_num)
        FOV_num = 1;
    end

    if exist('mouse_num','var') && exist('date_num','var')
        if ispc
            root_dir = '\\psy-chaos';
        elseif ismac
            root_dir = '/Volumes';
        end

        defaultDir = fullfile(root_dir,'kiralab','Lab','Imaging',mouseID,num2str(date_num));
        save_dir   = fullfile(root_dir,'kiralab','Lab','Imaging','BatchAcqObj');
    else
        error('Essential variables are missing!')
    end

    % FOV name
    if ~exist('FOV_name','var')
        FOV_name = sprintf('FOV%d_%05d',FOV_num,Acq_num);
    end

    Acq_name = [initials,sprintf('%03d',mouse_num),'_',num2str(date_num),'_',FOV_name];

    % create obj
    obj = Acquisition2P(Acq_name,@SK2Pinit,defaultDir);

    if ~exist('motionCorrectionFunction','var')
        % overwrite motion correction function
        obj.motionCorrectionFunction = @lucasKanade_plus_nonrigid;
    else
        obj.motionCorrectionFunction = motionCorrectionFunction;
    end

    fprintf('motionCorrectionFunction:\t%s\n',func2str(obj.motionCorrectionFunction));

    % select server_name: data2; scratch2; no_backup;
    if o2_flag
        fprintf('Will process movies saved @ %s\n',server_name)
        obj.defaultDir = changePath4Orchestra(obj.defaultDir,server_name);

        for i = 1:length(obj.Movies)
            obj.Movies{i} = changePath4Orchestra(obj.Movies{i},server_name);
        end
    end

    obj.save(save_dir)

end