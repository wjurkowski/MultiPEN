function MP = MultiPEN(analysisType, saveResults, varargin)
%function MP = MultiPEN(analysisType, outputDir, X, E, Y, featureNames, ...
%    lambdas, folds, numIter)
% Function to perform analysis of omics data using MultiPEN and
% the different type of analysis (specified by parameter 'analysisType')
% MultiPEN 0.0.2 computes feature selection from transcritpomics and 
% metabolomics data
% Written by Perla Rey, Agust 2016
%
% It uses following libraries:
% GenePEN
% TFOCS-1.3.1
% gaimc
% 

% INPUTS
%   analysisType    Options are: 
%                   'crossValidation', 'featureSelection'
%                   coming soon: 'GenePEN', 'RandomiseNetwork', 'ErdosRenyi'
%   outputDir       Output directory
%   X
%   E
%   Y
%   featureNames
%   lambdas         specify lambda(s)
%   folds           for cross validation
%   numIter         for optimisation, defaults is 100

%% VERIFY INPUT ARGUMENTS
switch analysisType
    case 'cross_validation'
        % cross validation needs parameters: 
        % X, E, Y, lambdas, folds, numIter (optional)
        if ~((length(varargin) == 5) || (length(varargin) == 6))
            error('The number of arguments is incorrect')
        else
            X = varargin{1};
            E = varargin{2};
            Y = varargin{3};
            lambdas = str2num(varargin{4});
            folds = str2num(varargin{5});
            if length(varargin) == 5
                numIter = 100;
            else
                numIter = str2num(varargin{6});
            end
        end
        
    case 'featureSelection'
        % featureSelection needs parameters:
        %X, E, Y, lambda, features, sampleAnnot, numIter (optional)
        if ~((length(varargin) == 6) || (length(varargin) == 7))
            error('The number of arguments is incorrect')
        else
            X = varargin{1};
            E = varargin{2};
            Y = varargin{3};
            lambda = str2num(varargin{4});
            features = varargin{5};
            samples = varargin{6};
            if length(varargin) == 6
                numIter = 100;
            else
                numIter = str2num(varargin{7});
            end
        end
    otherwise
        error('Please specify a valid analysis')
end
    
%% READ INPUT DATA
%  Input arguments passed from the system prompt will be received as strings
%  Thus, converting strings to double if required 

% X - expression data n-by-p
exist X 'var'
if ans
    if ~isa(X,'double')
        Xfile = X;     
        X = load(Xfile, '-ascii');
    end
end
 
%E - interaction matrix (network edges)
exist E 'var'
if ans
    if ~isa(E,'double')
        Efile = E;    
        E = load(Efile, '-ascii');
    end
end


%class - Y
exist Y 'var'
if ans
    if ~isa(Y,'double')
        Yfile = Y;
        Y = load(Yfile, '-ascii');
    end
end

whos lambda
% %lambdas for cross validation
% exist lambdas 'var'
% if ans
%     if ~isa(lambdas, 'double')
%         lambdas = str2num(lambdas);   
%     end
% end


% %folds for cross validation
% exist folds 'var'
% if ans
%     if ~isa(folds, 'double')
%         folds = str2num(folds);
%     end
% end

% Feature annotation
exist features 'var'
if ans
    if ~isa(features,'double')
        featureAnnotfile = features;           
        features = table2cell(readtable(featureAnnotfile, 'ReadVariableNames', false));
    end
end

% Sample annotation
exist samples 'var'
if ans
    if ~isa(samples,'double')
        samplesFile = samples;           
        samples = table2cell(readtable(samplesFile, 'ReadVariableNames', false));
    end
end




%% ADD PATH TO LIBRARIES
if ~isdeployed
    addpath('Libraries/')
    addpath('Libraries/fastGapFill/')
    addpath('Libraries/gaimc/')
    addpath('Libraries/GenePEN/')
    addpath('Libraries/TFOCS-1.3.1/')
end


%% Analysis

%If maximum number of iterations is not specified
if numIter == 0  
    % set the default value
    numIter = 3000; 
end

switch analysisType
    case 'hierarchical_clustering'
        
    
    case 'cross_validation'                
        %cross_validation for different lambdas
        fprintf('Performing cross validation... \n')        
        [~, ~, ~, outcome_stats] = cross_validation(X, E, Y, lambdas, folds, numIter);
        stats = table(outcome_stats(:,1), outcome_stats(:,2), outcome_stats(:,3), outcome_stats(:,4), outcome_stats(:,5), outcome_stats(:,6), ...
            'VariableNames', {'lambda' 'LCC' 'std_LCC' 'selected' 'AUC' 'std_AUC'});
        
        if ~strcmp(saveResults,'false')
            if strcmp(saveResults, 'true')
                outputDir = 'output_MultiPEN/cross_validation/';
            else
                outputDir = saveResults;
            end
            
            %check if output directory exists
            if exist(outputDir, 'dir') ~= 7
                mkdir(outputDir)
            end
                        
            % Statistics for cross validation
            fileName = [outputDir 'cross-validation_stats.txt'];
            writetable(stats, fileName, 'delimiter', '\t')
            fprintf('\tStatistics are saved to file: \n\t%s\n', ...
                fileName)
            fprintf('Following are the statistics for cross validation\n')
            display(stats)
                        
        end
        
        MP = outcome_stats;
        
          
    case 'featureSelection'
        %Feature selection for a specific lambda
        fprintf('Performing feature selection... \n')
        %FS is a table with columns: [name, weight, ranking]
        [FS, vts] = featureSelection(X, E, Y, features, lambda, numIter);
        
        %compute fold change
        [FS, higherControl, higherCases] = foldChange(FS, X, Y, samples);
        
        % WRITE feature selection (FS table) to file
        if ~strcmp(saveResults,'false')
            if strcmp(saveResults, 'true')
                outputDir = 'output_MultiPEN/feature_selection/';
            else
                outputDir = saveResults;
            end
            
            %check if output directory exists
            if exist(outputDir, 'dir') ~= 7
                mkdir(outputDir)
            end
            
            %feature's ranking
            %[name weight ranking]
            fileName = [outputDir 'MultiPEN-Rankings_lambda' num2str(lambda)];
            fprintf('Writing feature selection to file: \n\t%s\n',fileName)
            writetable(FS, [fileName '.txt'], 'delimiter', '\t');
            save([fileName '.mat'], 'FS')
            
            %intercept learnt from feature selection
            fileName = [outputDir 'MultiPEN-vts_lambda' num2str(lambda)];            
            dlmwrite([fileName '.txt'], vts, 'delimiter', '\t');    
            
            %% write separate tables for higherControl an higherCases
            fileName = [outputDir 'MultiPEN-Rankings_lambda' num2str(lambda) '_higher-in-control.txt'];
            fprintf('Writing feature selection to file: \n\t%s\n',fileName)
            writetable(higherControl, fileName, 'delimiter', '\t');
            
            fileName = [outputDir 'MultiPEN-Rankings_lambda' num2str(lambda) '_higher-in-cases.txt'];
            fprintf('Writing feature selection to file: \n\t%s\n',fileName)
            writetable(higherCases, fileName, 'delimiter', '\t');
            %
        end
                       
        MP = FS;

end