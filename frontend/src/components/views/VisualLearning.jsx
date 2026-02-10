import React, { useState, useEffect, useRef } from 'react';
import {
    Network, ZoomIn, ZoomOut, RotateCcw, Download,
    Maximize2, X, ChevronRight, Brain, Target,
    BookOpen, Loader2, Play, Eye, RefreshCw, AlertCircle
} from 'lucide-react';
import { getKnowledgeGraph, getRelatedTopics, getTopics, buildKnowledgeGraph } from '../../api';

const VisualLearning = ({
    projectId,
    topics = [],
    documentTopics = {},
    documents = [],
    onTopicSelect,
    onClose
}) => {
    const [viewMode, setViewMode] = useState('mindmap'); // 'mindmap', 'graph', 'flowchart'
    const [graphData, setGraphData] = useState(null);
    const [loading, setLoading] = useState(true);
    const [building, setBuilding] = useState(false);
    const [selectedNode, setSelectedNode] = useState(null);
    const [zoom, setZoom] = useState(1);
    const [pan, setPan] = useState({ x: 0, y: 0 });
    const [allTopics, setAllTopics] = useState([]);
    const [docTopicsMap, setDocTopicsMap] = useState({});
    const canvasRef = useRef(null);
    const containerRef = useRef(null);

    useEffect(() => {
        loadData();
    }, [projectId]);

    const loadData = async () => {
        setLoading(true);
        try {
            // First fetch topics from API
            const topicsData = await getTopics(projectId);
            
            let fetchedTopics = [];
            let fetchedDocTopics = {};
            
            if (topicsData?.all && topicsData?.by_doc) {
                fetchedTopics = topicsData.all;
                fetchedDocTopics = topicsData.by_doc;
            } else if (Array.isArray(topicsData)) {
                fetchedTopics = topicsData;
            }
            
            setAllTopics(fetchedTopics);
            setDocTopicsMap(fetchedDocTopics);
            
            // Now try to get knowledge graph
            try {
                const data = await getKnowledgeGraph(projectId);
                if (data?.graph?.nodes?.length > 0) {
                    setGraphData(data);
                } else {
                    // No graph yet - create one from topics
                    setGraphData({
                        graph: {
                            nodes: fetchedTopics.map((topic) => ({
                                id: topic,
                                label: topic,
                                type: 'topic',
                            })),
                            edges: [],
                        },
                    });
                }
            } catch (graphError) {
                console.error('Failed to load graph:', graphError);
                // Use topics as fallback
                setGraphData({
                    graph: {
                        nodes: fetchedTopics.map((topic) => ({
                            id: topic,
                            label: topic,
                            type: 'topic',
                        })),
                        edges: [],
                    },
                });
            }
        } catch (error) {
            console.error('Failed to load data:', error);
            setGraphData({ graph: { nodes: [], edges: [] } });
        } finally {
            setLoading(false);
        }
    };

    const handleBuildGraph = async () => {
        if (allTopics.length < 2) {
            return;
        }
        setBuilding(true);
        try {
            await buildKnowledgeGraph(projectId, allTopics, true);
            await loadData(); // Reload after building
        } catch (error) {
            console.error('Failed to build graph:', error);
        } finally {
            setBuilding(false);
        }
    };

    // Simple force-directed layout calculation
    const calculateLayout = () => {
        if (!graphData?.graph?.nodes) return [];

        const nodes = graphData.graph.nodes;
        const centerX = 400;
        const centerY = 300;
        const radius = Math.min(nodes.length * 30, 250);

        return nodes.map((node, idx) => {
            const angle = (2 * Math.PI * idx) / nodes.length;
            return {
                ...node,
                x: centerX + radius * Math.cos(angle),
                y: centerY + radius * Math.sin(angle),
            };
        });
    };

    const layoutNodes = calculateLayout();

    // Group topics by document for mind map
    // Uses fetched state (docTopicsMap/allTopics), falling back to props
    const getMindMapData = () => {
        const docGroups = {};
        const effectiveDocTopics = Object.keys(docTopicsMap).length > 0 ? docTopicsMap : documentTopics;
        const effectiveTopics = allTopics.length > 0 ? allTopics : topics;
        
        // Group topics by document
        Object.entries(effectiveDocTopics).forEach(([docId, topicsList]) => {
            const doc = documents.find(d => d.id === docId);
            if (doc && topicsList?.length > 0) {
                docGroups[docId] = {
                    name: doc.filename,
                    topics: topicsList.slice(0, 8), // Max 8 topics per doc for readability
                };
            }
        });

        // If no document grouping, use flat topic list
        if (Object.keys(docGroups).length === 0) {
            if (effectiveTopics.length === 0) {
                return { center: 'No Topics', branches: [] };
            }
            return {
                center: 'Your Learning',
                branches: effectiveTopics.slice(0, 12).map(topic => ({
                    name: topic,
                    children: [],
                })),
            };
        }

        return {
            center: 'Your Books',
            branches: Object.entries(docGroups).map(([docId, data]) => ({
                id: docId,
                name: data.name.length > 20 ? data.name.substring(0, 17) + '...' : data.name,
                fullName: data.name,
                children: data.topics.map(t => ({ name: t })),
            })),
        };
    };

    const mindMapData = getMindMapData();

    const handleZoom = (delta) => {
        setZoom(prev => Math.max(0.5, Math.min(2, prev + delta)));
    };

    const resetView = () => {
        setZoom(1);
        setPan({ x: 0, y: 0 });
    };

    const colors = [
        'from-blue-500 to-blue-600',
        'from-green-500 to-green-600',
        'from-purple-500 to-purple-600',
        'from-amber-500 to-amber-600',
        'from-pink-500 to-pink-600',
        'from-cyan-500 to-cyan-600',
        'from-red-500 to-red-600',
        'from-indigo-500 to-indigo-600',
    ];

    const borderColors = [
        'border-blue-300',
        'border-green-300',
        'border-purple-300',
        'border-amber-300',
        'border-pink-300',
        'border-cyan-300',
        'border-red-300',
        'border-indigo-300',
    ];

    if (loading) {
        return (
            <div className="h-full flex items-center justify-center bg-[#FDF6F0]">
                <div className="text-center">
                    <div className="relative w-16 h-16 mx-auto mb-4">
                        <div className="absolute inset-0 border-4 border-[#E6D5CC] rounded-full" />
                        <div className="absolute inset-0 border-4 border-[#C8A288] rounded-full border-t-transparent animate-spin" />
                        <Network className="absolute inset-0 m-auto h-6 w-6 text-[#C8A288]" />
                    </div>
                    <p className="text-[#8a6a5c]">Loading visualization...</p>
                </div>
            </div>
        );
    }

    return (
        <div className="h-full flex flex-col bg-[#FDF6F0]">
            {/* Header */}
            <div className="p-4 bg-white border-b border-[#E6D5CC] flex items-center justify-between">
                <div className="flex items-center gap-3">
                    <div className="h-10 w-10 bg-gradient-to-br from-[#C8A288] to-[#A08072] rounded-xl flex items-center justify-center">
                        <Network className="h-5 w-5 text-white" />
                    </div>
                    <div>
                        <h3 className="font-bold text-[#4A3B32]">Visual Learning</h3>
                        <p className="text-sm text-[#8a6a5c]">Explore topics and connections</p>
                    </div>
                </div>

                <div className="flex items-center gap-2">
                    {/* View Mode Toggle */}
                    <div className="flex bg-[#FDF6F0] rounded-lg p-1">
                        {[
                            { id: 'mindmap', icon: Brain, label: 'Mind Map' },
                            { id: 'graph', icon: Network, label: 'Graph' },
                        ].map(({ id, icon: Icon, label }) => (
                            <button
                                key={id}
                                onClick={() => setViewMode(id)}
                                className={`px-3 py-1.5 rounded-md text-sm font-medium transition-colors flex items-center gap-1.5 ${
                                    viewMode === id
                                        ? 'bg-[#C8A288] text-white'
                                        : 'text-[#8a6a5c] hover:bg-[#E6D5CC]'
                                }`}
                            >
                                <Icon className="h-4 w-4" />
                                <span className="hidden sm:inline">{label}</span>
                            </button>
                        ))}
                    </div>

                    {/* Zoom Controls */}
                    <div className="flex items-center gap-1 bg-[#FDF6F0] rounded-lg p-1">
                        <button
                            onClick={() => handleZoom(-0.1)}
                            className="p-1.5 hover:bg-[#E6D5CC] rounded-md transition-colors"
                        >
                            <ZoomOut className="h-4 w-4 text-[#8a6a5c]" />
                        </button>
                        <span className="px-2 text-sm text-[#4A3B32] font-medium">
                            {Math.round(zoom * 100)}%
                        </span>
                        <button
                            onClick={() => handleZoom(0.1)}
                            className="p-1.5 hover:bg-[#E6D5CC] rounded-md transition-colors"
                        >
                            <ZoomIn className="h-4 w-4 text-[#8a6a5c]" />
                        </button>
                        <button
                            onClick={resetView}
                            className="p-1.5 hover:bg-[#E6D5CC] rounded-md transition-colors"
                        >
                            <RotateCcw className="h-4 w-4 text-[#8a6a5c]" />
                        </button>
                    </div>

                    {onClose && (
                        <button
                            onClick={onClose}
                            className="p-2 hover:bg-[#FDF6F0] rounded-lg transition-colors"
                        >
                            <X className="h-5 w-5 text-[#8a6a5c]" />
                        </button>
                    )}

                    {/* Build Graph Button */}
                    {allTopics.length >= 2 && (!graphData?.graph?.edges || graphData.graph.edges.length === 0) && (
                        <button
                            onClick={handleBuildGraph}
                            disabled={building}
                            className="px-3 py-1.5 bg-[#C8A288] text-white rounded-lg text-sm font-medium hover:bg-[#A08072] transition-colors flex items-center gap-1.5 disabled:opacity-50"
                        >
                            {building ? <Loader2 className="h-4 w-4 animate-spin" /> : <Network className="h-4 w-4" />}
                            {building ? 'Building...' : 'Build Connections'}
                        </button>
                    )}
                </div>
            </div>

            {/* Canvas */}
            <div 
                ref={containerRef}
                className="flex-1 overflow-hidden relative"
                style={{ cursor: 'grab' }}
            >
                {/* Empty state when no topics */}
                {mindMapData.branches.length === 0 && layoutNodes.length === 0 ? (
                    <div className="absolute inset-0 flex items-center justify-center">
                        <div className="text-center">
                            <Network className="w-16 h-16 text-[#E6D5CC] mx-auto mb-4" />
                            <p className="text-[#4A3B32] font-semibold mb-2">No Topics Available</p>
                            <p className="text-sm text-[#8a6a5c] mb-4 max-w-sm">
                                Upload documents and wait for topics to be generated. The mind map will appear here automatically.
                            </p>
                            <button
                                onClick={loadData}
                                className="px-4 py-2 bg-[#C8A288] text-white rounded-lg hover:bg-[#A08072] transition-colors flex items-center gap-2 mx-auto"
                            >
                                <RefreshCw className="h-4 w-4" />
                                Refresh
                            </button>
                        </div>
                    </div>
                ) : (
                <div
                    className="absolute inset-0 flex items-center justify-center"
                    style={{
                        transform: `scale(${zoom}) translate(${pan.x}px, ${pan.y}px)`,
                        transition: 'transform 0.1s ease-out',
                    }}
                >
                    {viewMode === 'mindmap' && (
                        <div className="relative" style={{ minWidth: '800px', minHeight: '600px' }}>
                            {/* Center Node */}
                            <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 z-10">
                                <div className="px-6 py-4 bg-gradient-to-br from-[#C8A288] to-[#A08072] text-white rounded-2xl shadow-lg font-bold text-lg">
                                    {mindMapData.center}
                                </div>
                            </div>

                            {/* Branches */}
                            {mindMapData.branches.map((branch, idx) => {
                                const angle = (2 * Math.PI * idx) / mindMapData.branches.length - Math.PI / 2;
                                const branchRadius = 180;
                                const x = Math.cos(angle) * branchRadius;
                                const y = Math.sin(angle) * branchRadius;

                                return (
                                    <div key={idx}>
                                        {/* Connection Line */}
                                        <svg
                                            className="absolute left-1/2 top-1/2 overflow-visible pointer-events-none"
                                            style={{ transform: 'translate(-50%, -50%)' }}
                                        >
                                            <line
                                                x1="0"
                                                y1="0"
                                                x2={x}
                                                y2={y}
                                                stroke="#E6D5CC"
                                                strokeWidth="2"
                                            />
                                        </svg>

                                        {/* Branch Node */}
                                        <div
                                            className="absolute"
                                            style={{
                                                left: `calc(50% + ${x}px)`,
                                                top: `calc(50% + ${y}px)`,
                                                transform: 'translate(-50%, -50%)',
                                            }}
                                        >
                                            <div
                                                className={`px-4 py-2 bg-gradient-to-br ${colors[idx % colors.length]} text-white rounded-xl shadow-md font-medium text-sm whitespace-nowrap cursor-pointer hover:scale-105 transition-transform`}
                                                onClick={() => setSelectedNode(branch)}
                                                title={branch.fullName || branch.name}
                                            >
                                                {branch.name}
                                            </div>

                                            {/* Child Nodes (Topics) */}
                                            {branch.children?.map((child, childIdx) => {
                                                const childAngle = angle + (childIdx - branch.children.length / 2) * 0.3;
                                                const childRadius = 100;
                                                const childX = Math.cos(childAngle) * childRadius;
                                                const childY = Math.sin(childAngle) * childRadius;

                                                return (
                                                    <div key={childIdx}>
                                                        {/* Child Connection */}
                                                        <svg
                                                            className="absolute overflow-visible pointer-events-none"
                                                            style={{
                                                                left: '50%',
                                                                top: '50%',
                                                                transform: 'translate(-50%, -50%)',
                                                            }}
                                                        >
                                                            <line
                                                                x1="0"
                                                                y1="0"
                                                                x2={childX}
                                                                y2={childY}
                                                                stroke="#E6D5CC"
                                                                strokeWidth="1"
                                                            />
                                                        </svg>

                                                        {/* Child Node */}
                                                        <div
                                                            className="absolute"
                                                            style={{
                                                                left: `calc(50% + ${childX}px)`,
                                                                top: `calc(50% + ${childY}px)`,
                                                                transform: 'translate(-50%, -50%)',
                                                            }}
                                                        >
                                                            <button
                                                                onClick={() => onTopicSelect?.(child.name)}
                                                                className={`px-3 py-1.5 bg-white border-2 ${borderColors[idx % borderColors.length]} rounded-lg text-xs font-medium text-[#4A3B32] whitespace-nowrap hover:scale-105 transition-transform shadow-sm`}
                                                            >
                                                                {child.name.length > 15 ? child.name.substring(0, 12) + '...' : child.name}
                                                            </button>
                                                        </div>
                                                    </div>
                                                );
                                            })}
                                        </div>
                                    </div>
                                );
                            })}
                        </div>
                    )}

                    {viewMode === 'graph' && (
                        <div className="relative" style={{ minWidth: '800px', minHeight: '600px' }}>
                            {/* Draw edges first */}
                            <svg className="absolute inset-0 w-full h-full pointer-events-none">
                                {graphData?.graph?.edges?.map((edge, idx) => {
                                    const sourceNode = layoutNodes.find(n => n.id === edge.from_topic);
                                    const targetNode = layoutNodes.find(n => n.id === edge.to_topic);
                                    if (!sourceNode || !targetNode) return null;

                                    return (
                                        <line
                                            key={idx}
                                            x1={sourceNode.x}
                                            y1={sourceNode.y}
                                            x2={targetNode.x}
                                            y2={targetNode.y}
                                            stroke="#C8A288"
                                            strokeWidth="2"
                                            opacity="0.5"
                                        />
                                    );
                                })}
                            </svg>

                            {/* Draw nodes */}
                            {layoutNodes.map((node, idx) => (
                                <button
                                    key={node.id}
                                    onClick={() => onTopicSelect?.(node.id)}
                                    className={`absolute px-3 py-2 bg-white border-2 border-[#C8A288] rounded-xl text-sm font-medium text-[#4A3B32] shadow-md hover:scale-110 transition-transform`}
                                    style={{
                                        left: node.x,
                                        top: node.y,
                                        transform: 'translate(-50%, -50%)',
                                    }}
                                >
                                    {node.label?.length > 15 ? node.label.substring(0, 12) + '...' : node.label}
                                </button>
                            ))}
                        </div>
                    )}
                </div>
                )}
            </div>

            {/* Selected Node Panel */}
            {selectedNode && (
                <div className="absolute bottom-4 left-4 right-4 md:left-auto md:right-4 md:w-80 bg-white rounded-xl border border-[#E6D5CC] shadow-lg p-4 animate-in slide-in-from-bottom-4">
                    <div className="flex items-center justify-between mb-3">
                        <h4 className="font-bold text-[#4A3B32]">{selectedNode.fullName || selectedNode.name}</h4>
                        <button
                            onClick={() => setSelectedNode(null)}
                            className="p-1 hover:bg-[#FDF6F0] rounded-lg"
                        >
                            <X className="h-4 w-4 text-[#8a6a5c]" />
                        </button>
                    </div>
                    {selectedNode.children?.length > 0 && (
                        <>
                            <p className="text-sm text-[#8a6a5c] mb-2">{selectedNode.children.length} topics</p>
                            <div className="flex flex-wrap gap-1.5 max-h-32 overflow-y-auto">
                                {selectedNode.children.map((child, idx) => (
                                    <button
                                        key={idx}
                                        onClick={() => onTopicSelect?.(child.name)}
                                        className="px-2 py-1 bg-[#FDF6F0] hover:bg-[#E6D5CC] rounded-lg text-xs text-[#4A3B32] transition-colors"
                                    >
                                        {child.name}
                                    </button>
                                ))}
                            </div>
                        </>
                    )}
                    <button
                        onClick={() => {
                            onTopicSelect?.(selectedNode.children?.[0]?.name || selectedNode.name);
                            setSelectedNode(null);
                        }}
                        className="w-full mt-3 py-2 bg-[#C8A288] text-white rounded-lg font-medium hover:bg-[#B08B72] transition-colors flex items-center justify-center gap-2"
                    >
                        <Play className="h-4 w-4" />
                        Start Learning
                    </button>
                </div>
            )}

            {/* Legend */}
            <div className="p-3 bg-white border-t border-[#E6D5CC] flex items-center justify-center gap-6 text-xs text-[#8a6a5c]">
                <span className="flex items-center gap-1.5">
                    <div className="h-3 w-3 rounded-full bg-gradient-to-br from-[#C8A288] to-[#A08072]" />
                    Central Concept
                </span>
                <span className="flex items-center gap-1.5">
                    <div className="h-3 w-3 rounded-full bg-gradient-to-br from-blue-500 to-blue-600" />
                    Book/Category
                </span>
                <span className="flex items-center gap-1.5">
                    <div className="h-3 w-3 rounded border-2 border-blue-300 bg-white" />
                    Topic
                </span>
            </div>
        </div>
    );
};

export default VisualLearning;
