import React from 'react';
import {
    View,
    Text
} from 'react-native'

import {
    TabBar,
    SearchBar
} from 'antd-mobile'

export default class BasicTabBarExample extends React.Component{
    constructor(props){
        super(props);
        this.state = {
            selectedTab:'redTab'
        }
    }

    renderContent(pageText) {
        return (
            <View style={{ flex: 1, alignItems: 'center', backgroundColor: 'white' }}>
                <SearchBar
                    placeholder="搜索"
                    showCancelButton
                />
                <Text style={{ margin: 50 }}>{pageText}</Text>
            </View>
        );
    }

    onChangeTab(tabName){
        this.setState({
            selectedTab:tabName
        })
    }

    render(){
        return (
            <TabBar
            unselectedTintColor="#949494"
            tintColor="#33A3F4"
            barTintColor="#ccc"
            >
                <TabBar.Item
                title="生活"
                icon={require("../../assets/images/alipay.png")}
                selectedIcon={require("../../assets/images/alipay_sel.png")}
                selected={this.state.selectedTab === 'blueTab'}
                onPress={()=>this.onChangeTab('blueTab')}
                >
                    {this.renderContent("生活")}
                </TabBar.Item>
                <TabBar.Item
                    icon={require('../../assets/images/koubei.png')}
                    selectedIcon={require('../../assets/images/koubei_sel.png')}
                    title="口碑"
                    badge={2}
                    selected={this.state.selectedTab === 'redTab'}
                    onPress={() => this.onChangeTab('redTab')}
                >
                    {this.renderContent('口碑 Tab')}
                </TabBar.Item>
                <TabBar.Item
                    icon={require('../../assets/images/friend.png')}
                    selectedIcon={require('../../assets/images/friend_sel.png')}
                    title="朋友"
                    selected={this.state.selectedTab === 'greenTab'}
                    onPress={() => this.onChangeTab('greenTab')}
                >
                    {this.renderContent('朋友 Tab')}
                </TabBar.Item>
                <TabBar.Item
                    icon={require('../../assets/images/busi.png')}
                    selectedIcon={require('../../assets/images/busi_sel.png')}
                    title="我的"
                    selected={this.state.selectedTab === 'yellowTab'}
                    onPress={() => this.onChangeTab('yellowTab')}
                >
                    {this.renderContent('我的 Tab')}
                </TabBar.Item>
            </TabBar>
        )
    }
}





























