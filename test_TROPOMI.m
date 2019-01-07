% script updated by Lorena Castro from the University of Iowa to subset TROPOMI data
% this version of the script does not allow downloading data on the flight, these should be retrieved separately

L2dir = '/Dedicated/jwang-data/lcastro/TROPOMI/NO2/source_data/CA/'; % raw L2 data directory,
L2gdir = '/Dedicated/jwang-data/lcastro/general_regrid/matlab_approach/L2g/'; % intermediate data, or L2g
L3dir = '/Dedicated/jwang-data/lcastro/general_regrid/matlab_approach/L3/'; % regridded data, or L3

%if_download = false;
if_subset = true;
if_regrid = true; 
if_plot = true;

%% --- download OMNO2
%if if_download
%    inp_download = [];
%    % CONUS
%    inp_download.MinLat = 25;
%    inp_download.MaxLat = 50;
%    inp_download.MinLon = -130;
%    inp_download.MaxLon = -63;
%    
%    inp_download.if_download_xml = true;
%    inp_download.if_download_he5 = true;
%    
%    inp_download.swath_BDR_fn = '/Dedicated/jwang-data/lcastro/general_regrid/matlab_approach/Important_constant/OMI_BDR.mat';
%    inp_download.url0 = 'https://aura.gesdisc.eosdis.nasa.gov/data/Aura_OMI_Level2/OMNO2.003/';
%    inp_download.L2dir = L2dir;
%    
%    for iyear = 2018:2018
%        inp_download.Startdate = [iyear 1 1];
%        inp_download.Enddate = [iyear 1 31];
%        inp_download.if_parallel = false;
%        % parallel download is fast, but
%        output_download = F_download_OMI(inp_download);
%        save([L2dir,num2str(iyear),'output_download.mat'],'output_download')
%    end
%end

if if_subset
    inp_subset = [];
    % CONUS
    inp_subset.MinLat = 25;
    inp_subset.MaxLat = 50;
    inp_subset.MinLon = -130;
    inp_subset.MaxLon = -63;
    
    % flags MinQA, MaxVZA, MinNO2 and MaxNO2 were added for TROPOMI QA
    inp_subset.MaxCF = 0.3;
    inp_subset.MinQA = 0.5;
    inp_subset.MaxSZA = 70;
    inp_subset.MaxVZA = 70;
    inp_subset.MinNO2 = 0.0;
    inp_subset.MaxNO2 = 20;
    
    inp_subset.usextrack = 1:450;
    
    inp_subset.L2dir = L2dir;
    
    for iyear = 2018:2018
        inp_subset.Startdate = [iyear 7 1];
        inp_subset.Enddate = [iyear 7 2]; 
        output_subset = F_subset_TROPOMI(inp_subset);
        
        L2g_fn = ['CONUS_',num2str(iyear),'.mat'];
        save([L2gdir,L2g_fn],'inp_subset','output_subset')
    end 
    
end


%% regrid subsetted L2 data (or L2g data) into L3 data, save L3 monthly
if if_regrid
    clc
    for iyear = 2018:2018
        L2g_fn = ['CONUS_',num2str(iyear),'.mat'];
        load([L2gdir,L2g_fn],'inp_subset','output_subset')
        inp_regrid = [];
        
        % Resolution of oversampled L3 data?
        inp_regrid.Res = 0.02; % in degree
                
        % California area
        inp_regrid.MinLon = -120;
        inp_regrid.MaxLon = -114;
        inp_regrid.MinLat = 31;
        inp_regrid.MaxLat = 35;
        
        inp_regrid.MinQA = 0.5;
        inp_regrid.MaxCF = 0.3;
        inp_regrid.MaxSZA = 70;
        inp_regrid.MaxVZA = 70;
        inp_regrid.MinNO2 = 0.0;
    	inp_regrid.MaxNO2 = 20;
        
        inp_regrid.vcdname = 'colno2';
        inp_regrid.vcderrorname = 'colno2error';
        inp_regrid.if_parallel = true;
        
        end_date_month = [31 28 31 30 31 30 31 31 30 31 30 31];
        if iyear == 2004 || iyear == 2008 || iyear == 2016
            end_date_month = [31 29 31 30 31 30 31 31 30 31 30 31];
        end
        for imonth = 7:7
            inp_regrid.Startdate = [iyear imonth 1];
            inp_regrid.Enddate = [iyear imonth end_date_month(imonth)];
            output_regrid = F_regrid_TROPOMI(inp_regrid,output_subset);
            L3_fn = ['California_',num2str(iyear),'_',num2str(imonth),'_CA.mat'];
            save([L3dir,L3_fn],'inp_regrid','output_regrid')
        end
    end
end
%%

%%
if if_plot
    clear output_regrid    
    for iyear = 2018:2018
        for imonth = 7:7
            L3_fn = ['California_',num2str(iyear),'_',num2str(imonth),'_CA.mat'];
            if ~exist('output_regrid','var')
                load([L3dir,L3_fn],'inp_regrid','output_regrid')
                A = output_regrid.A;
                B = output_regrid.B;
                D = output_regrid.D;
            else
                load([L3dir,L3_fn],'inp_regrid','output_regrid')
                A = A+output_regrid.A;
                B = B+output_regrid.B;
                D = D+output_regrid.D;
            end
        end
    end
    
    C = A./B;
    Clim = [0 0.000141508];% min/max plotted nh3 column
	% shape file for US states
	US_states = shaperead('/Dedicated/jwang-data/lcastro/general_regrid/matlab_approach/US_state/cb_2016_us_state_20m.shp');
	opengl software
	close all
	figure('unit','inch','color','w','position',[0 1 8 6])

	h = pcolor(output_regrid.xgrid,output_regrid.ygrid,...
    	double(C/1e16));
	set(h,'edgecolor','none');
	colormap('parula')
	caxis(Clim/1e16)

	hc = colorbar('south');
	set(hc,'position',[0.35 0.03 0.3 0.02])
	set(get(hc,'xlabel'),'string','Ammonia column [10^{16} molec/cm2]')
	hold on
	for istate = 1:length(US_states)
    	plot(US_states(istate).X,US_states(istate).Y,'color','w')
	end
	alpha(h,0.8)
	addpath('/Dedicated/jwang-data/lcastro/general_regrid/matlab_approach/plot/')
	plot_google_map('MapType','terrain')
	xlim([inp_regrid.MinLon inp_regrid.MaxLon])
	ylim([inp_regrid.MinLat inp_regrid.MaxLat])
	pos = get(gca,'position');
	set(gca,'position',[pos(1) pos(2)+0.05 pos(3:4)])

end
